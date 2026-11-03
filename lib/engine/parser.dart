/// Schedule file parser. Pure Dart, no Flutter imports.
///
/// A schedule file is Markdown with exactly one fenced code block whose info
/// string is `routine`. That block is YAML. See `docs/specs.md` § 1.
library;

import 'package:yaml/yaml.dart';

import 'models.dart';

const _topLevelKeys = ['bedtime', 'wake_target', 'day_types', 'blocks'];

const _blockKeys = [
  'id',
  'name',
  'detail',
  'minutes',
  'min',
  'priority',
  'only_on',
  'skip_on',
  'right_after',
  'latest_start',
  'at',
  'category',
  'notify',
];

/// Parses a schedule file. Collects every error it finds and never guesses:
/// [ParseResult.schedule] is set only when there are no errors.
ParseResult parseSchedule(String source) => _Parser(source).run();

/// A fenced code block found in the Markdown.
class _Fence {
  _Fence(this.openLine, this.bodyLines, {required this.closed});

  /// 1-based line of the opening fence.
  final int openLine;
  final List<String> bodyLines;
  final bool closed;
}

class _Parser {
  _Parser(this.source);

  final String source;
  final List<ScheduleError> errors = [];

  /// 1-based file line of the first YAML line.
  int _yamlFirstLine = 1;

  /// Every block that had an id, valid or not, so reference checks don't
  /// report a second error for a block that already has one.
  final List<({String id, String name, int line})> _written = [];

  void _error(int line, String message, {String? suggestion}) {
    errors.add(ScheduleError(line: line, message: message, suggestion: suggestion));
  }

  int _lineOf(YamlNode node) => _yamlFirstLine + node.span.start.line;

  ParseResult run() {
    final lines = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    var fences = _findRoutineFences(lines, respectNesting: true);
    // An AI answer is sometimes wrapped in an outer code block. If nothing was
    // found at the top level, look inside other blocks too.
    if (fences.isEmpty) fences = _findRoutineFences(lines, respectNesting: false);

    if (fences.isEmpty) {
      return const ParseResult(
        errors: [
          ScheduleError(
            line: 1,
            message:
                "There's no Enso schedule in this text. "
                'A schedule is a code block that starts with ```routine.',
            kind: ScheduleErrorKind.noRoutineBlock,
          ),
        ],
      );
    }

    for (final extra in fences.skip(1)) {
      _error(
        extra.openLine,
        'This is a second routine block. A schedule file has exactly one, '
        'starting on line ${fences.first.openLine}.',
      );
    }

    final fence = fences.first;
    if (!fence.closed) {
      _error(
        fence.openLine,
        'The routine block that starts on line ${fence.openLine} is never closed. '
        'Add a line with ``` after the last block.',
      );
    }
    _yamlFirstLine = fence.openLine + 1;

    final schedule = _parseYaml(fence);
    if (errors.isNotEmpty || schedule == null) {
      errors.sort((a, b) => a.line.compareTo(b.line));
      return ParseResult(errors: List.unmodifiable(errors));
    }
    return ParseResult(schedule: schedule);
  }

  // ---------------------------------------------------------------------------
  // Markdown fences

  static final _openFence = RegExp(r'^ {0,3}(`{3,}|~{3,})\s*([^`\s]*)');

  List<_Fence> _findRoutineFences(List<String> lines, {required bool respectNesting}) {
    final found = <_Fence>[];
    var i = 0;
    while (i < lines.length) {
      final open = _openFence.firstMatch(lines[i]);
      if (open == null) {
        i++;
        continue;
      }
      final marker = open.group(1)!;
      final info = open.group(2)!.toLowerCase();
      final isRoutine = info == 'routine';
      if (!isRoutine && !respectNesting) {
        i++;
        continue;
      }
      final closeFence = RegExp('^ {0,3}${RegExp.escape(marker[0])}{${marker.length},}\\s*\$');
      final body = <String>[];
      var j = i + 1;
      var closed = false;
      while (j < lines.length) {
        if (closeFence.hasMatch(lines[j])) {
          closed = true;
          break;
        }
        body.add(lines[j]);
        j++;
      }
      if (isRoutine) found.add(_Fence(i + 1, body, closed: closed));
      i = j + 1;
    }
    return found;
  }

  // ---------------------------------------------------------------------------
  // YAML

  Schedule? _parseYaml(_Fence fence) {
    final text = fence.bodyLines.join('\n');
    if (text.trim().isEmpty) {
      _error(fence.openLine, 'The routine block is empty.');
      return null;
    }

    final YamlNode root;
    try {
      root = loadYamlNode(text);
    } on YamlException catch (e) {
      final line = _yamlFirstLine + (e.span?.start.line ?? 0);
      _error(line, "This line isn't valid YAML: ${_cleanYamlMessage(e.message)}.");
      return null;
    }

    if (root is! YamlMap) {
      _error(_yamlFirstLine, 'The routine block should start with bedtime, day_types and blocks.');
      return null;
    }

    _checkUnknownKeys(root, _topLevelKeys, 'The schedule');

    final bedtime = _requiredTime(root, 'bedtime', _yamlFirstLine, 'bedtime', example: '22:30');
    final wakeNode = root.nodes['wake_target'];
    ClockTime? wakeTarget;
    if (wakeNode != null) {
      wakeTarget = _time(wakeNode, 'wake_target', example: '06:30');
    }
    final dayTypes = _dayTypes(root);
    final blocks = _blocks(root, dayTypes);

    if (bedtime != null && blocks != null) {
      _checkPinned(blocks, bedtime);
    }

    if (errors.isNotEmpty || bedtime == null || dayTypes == null || blocks == null) {
      return null;
    }
    return Schedule(
      bedtime: bedtime,
      wakeTarget: wakeTarget ?? bedtime.addMinutes(-8 * 60),
      dayTypes: List.unmodifiable(dayTypes),
      blocks: List.unmodifiable(blocks),
    );
  }

  String _cleanYamlMessage(String message) {
    final trimmed = message.trim();
    final first = trimmed.isEmpty ? 'unreadable' : trimmed[0].toLowerCase() + trimmed.substring(1);
    return first.endsWith('.') ? first.substring(0, first.length - 1) : first;
  }

  void _checkUnknownKeys(YamlMap map, List<String> allowed, String owner) {
    for (final entry in map.nodes.entries) {
      final keyNode = entry.key as YamlNode;
      final key = keyNode.value?.toString() ?? '';
      if (allowed.contains(key)) continue;
      _error(
        _lineOf(keyNode),
        "$owner has a field called $key, which Enso doesn't know.",
        suggestion: closestMatch(key, allowed),
      );
    }
  }

  ClockTime? _requiredTime(
    YamlMap map,
    String key,
    int fallbackLine,
    String label, {
    required String example,
  }) {
    final node = map.nodes[key];
    if (node == null || node.value == null) {
      _error(fallbackLine, 'The schedule has no $label. Add one, for example $key: "$example".');
      return null;
    }
    return _time(node, label, example: example);
  }

  ClockTime? _time(YamlNode node, String label, {required String example}) {
    final value = node.value;
    final parsed = value is String ? ClockTime.tryParse(value) : null;
    if (parsed == null) {
      _error(
        _lineOf(node),
        '$label should be a 24-hour time in quotes like "$example", but it is ${_show(value)}.',
      );
    }
    return parsed;
  }

  List<String>? _dayTypes(YamlMap root) {
    final node = root.nodes['day_types'];
    if (node == null || node.value == null) {
      _error(
        _yamlFirstLine,
        'The schedule has no day_types. Add the kinds of day you pick at check-in, '
        'for example day_types: [gym, rest].',
      );
      return null;
    }
    final list = _stringList(node, 'day_types');
    if (list == null) return null;
    if (list.isEmpty) {
      _error(
        _lineOf(node),
        'day_types is empty. List at least one kind of day, for example [normal].',
      );
      return null;
    }
    final seen = <String>{};
    for (final t in list) {
      if (!seen.add(t)) {
        _error(_lineOf(node), 'day_types lists $t twice.');
      }
    }
    return list;
  }

  /// Reads a list of short names. A single name without brackets is accepted
  /// as a one-item list.
  List<String>? _stringList(YamlNode node, String label) {
    if (node is YamlScalar && node.value is String) return [node.value as String];
    if (node is! YamlList) {
      _error(
        _lineOf(node),
        '$label should be a list like [gym, rest], but it is ${_show(node.value)}.',
      );
      return null;
    }
    final out = <String>[];
    var ok = true;
    for (final item in node.nodes) {
      final v = item.value;
      if (v is String && v.trim().isNotEmpty) {
        out.add(v.trim());
      } else {
        _error(_lineOf(item), '$label should only contain short names, but it has ${_show(v)}.');
        ok = false;
      }
    }
    return ok ? out : null;
  }

  // ---------------------------------------------------------------------------
  // Blocks

  List<BlockDef>? _blocks(YamlMap root, List<String>? dayTypes) {
    final node = root.nodes['blocks'];
    if (node == null || node.value == null) {
      _error(
        _yamlFirstLine,
        'The schedule has no blocks. Add a blocks: list with at least one block.',
      );
      return null;
    }
    if (node is! YamlList) {
      _error(_lineOf(node), 'blocks should be a list, with one block per line starting with "- ".');
      return null;
    }
    if (node.nodes.isEmpty) {
      _error(_lineOf(node), 'blocks is empty. Add at least one block.');
      return null;
    }

    final startErrors = errors.length;
    final parsed = <BlockDef>[];
    for (var i = 0; i < node.nodes.length; i++) {
      final block = _block(node.nodes[i], i + 1);
      if (block != null) parsed.add(block);
    }
    final blocksValid = errors.length == startErrors;

    _checkUniqueIds();
    _checkReferences(parsed, dayTypes);

    return blocksValid ? parsed : null;
  }

  BlockDef? _block(YamlNode node, int index) {
    final line = _lineOf(node);
    if (node is! YamlMap) {
      _error(line, 'Block $index should look like {id: ..., name: ..., minutes: ...}.');
      return null;
    }

    final id = _text(node, 'id');
    final name = _text(node, 'name');
    final label = name ?? id ?? 'Block $index';
    if (id != null) _written.add((id: id, name: label, line: line));
    final start = errors.length;

    _checkUnknownKeys(node, _blockKeys, label);

    if (id == null) {
      _error(
        line,
        '$label has no id. Add a short unique name, for example id: ${_suggestId(name)}.',
      );
    }
    if (name == null) {
      _error(line, '${id ?? 'Block $index'} has no name. Add the label to show on screen.');
    }

    final detailNode = node.nodes['detail'];
    String? detail;
    if (detailNode != null && detailNode.value != null) {
      final v = detailNode.value;
      if (v is String || v is num) {
        detail = v.toString();
      } else {
        _error(_lineOf(detailNode), '$label has a detail that is not text.');
      }
    }

    final minutesNode = node.nodes['minutes'];
    int? minutes;
    if (minutesNode == null || minutesNode.value == null) {
      _error(
        line,
        '$label has no minutes. Add how long it usually takes, for example minutes: 30.',
      );
    } else {
      minutes = _int(
        minutesNode,
        '$label has minutes: ${_show(minutesNode.value)}. '
        'It should be a whole number of minutes above 0.',
        min: 1,
      );
    }

    final minNode = node.nodes['min'];
    int? min;
    if (minNode != null && minNode.value != null) {
      min = _int(
        minNode,
        '$label has min: ${_show(minNode.value)}. '
        'It should be a whole number of minutes, 0 or more.',
        min: 0,
      );
      if (min != null && minutes != null && min > minutes) {
        _error(
          _lineOf(minNode),
          '$label can shrink to $min minutes, but it only lasts $minutes. min must not be larger than minutes.',
        );
      }
    }

    final priorityNode = node.nodes['priority'];
    int? priority;
    if (priorityNode != null && priorityNode.value != null) {
      priority = _int(
        priorityNode,
        '$label has priority: ${_show(priorityNode.value)}. '
        'It should be a whole number from 1 (cut last) to 9 (cut first).',
        min: 1,
        max: 9,
      );
    }
    if (minNode != null &&
        minNode.value != null &&
        (priorityNode == null || priorityNode.value == null)) {
      _error(
        _lineOf(minNode),
        '$label can be shortened but has no priority. Add priority: 1 (cut last) to 9 (cut first).',
      );
    }

    final onlyOn = _optionalList(node, 'only_on', label);
    final skipOn = _optionalList(node, 'skip_on', label);

    final rightAfterNode = node.nodes['right_after'];
    String? rightAfter;
    if (rightAfterNode != null && rightAfterNode.value != null) {
      final v = rightAfterNode.value;
      if (v is String || v is num) {
        rightAfter = v.toString().trim();
      } else {
        _error(_lineOf(rightAfterNode), '$label has a right_after that is not a block id.');
      }
    }

    ClockTime? latestStart;
    final latestNode = node.nodes['latest_start'];
    if (latestNode != null && latestNode.value != null) {
      latestStart = _time(latestNode, '$label latest_start', example: '14:00');
    }

    ClockTime? at;
    final atNode = node.nodes['at'];
    if (atNode != null && atNode.value != null) {
      at = _time(atNode, '$label at', example: '09:00');
    }

    Category? category;
    final categoryNode = node.nodes['category'];
    if (categoryNode != null && categoryNode.value != null) {
      final raw = categoryNode.value.toString().trim();
      final c = Category.tryParse(raw);
      final allowed = Category.fileValues.map((c) => c.name).toList();
      if (c == null || c == Category.errand) {
        _error(
          _lineOf(categoryNode),
          c == Category.errand
              ? '$label has category: errand, which is kept for errands added at check-in. '
                    'Use one of ${allowed.join(', ')}.'
              : "$label has category: $raw, which isn't one of ${allowed.join(', ')}.",
          suggestion: c == Category.errand ? null : closestMatch(raw, allowed),
        );
      } else {
        category = c;
      }
    }

    var notify = true;
    final notifyNode = node.nodes['notify'];
    if (notifyNode != null && notifyNode.value != null) {
      final v = notifyNode.value;
      if (v is bool) {
        notify = v;
      } else {
        _error(_lineOf(notifyNode), '$label has notify: ${_show(v)}. It should be true or false.');
      }
    }

    if (errors.length != start || id == null || name == null || minutes == null) return null;
    return BlockDef(
      id: id,
      name: name,
      detail: detail,
      minutes: minutes,
      min: min,
      priority: priority,
      onlyOn: onlyOn ?? const {},
      skipOn: skipOn ?? const {},
      rightAfter: rightAfter,
      latestStart: latestStart,
      at: at,
      category: category,
      notify: notify,
      line: line,
    );
  }

  String _suggestId(String? name) {
    if (name == null) return 'breakfast';
    final id = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return id.isEmpty ? 'breakfast' : id;
  }

  /// Reads a required-looking text field. Returns null if absent or empty.
  /// Reports an error if present but not text.
  String? _text(YamlMap map, String key) {
    final node = map.nodes[key];
    if (node == null || node.value == null) return null;
    final v = node.value;
    if (v is String || v is num) {
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }
    _error(_lineOf(node), '$key should be text, but it is ${_show(v)}.');
    return null;
  }

  int? _int(YamlNode node, String message, {required int min, int? max}) {
    final v = node.value;
    if (v is int && v >= min && (max == null || v <= max)) return v;
    _error(_lineOf(node), message);
    return null;
  }

  Set<String>? _optionalList(YamlMap map, String key, String label) {
    final node = map.nodes[key];
    if (node == null || node.value == null) return null;
    final list = _stringList(node, '$label $key');
    return list?.toSet();
  }

  // ---------------------------------------------------------------------------
  // Cross-block checks

  void _checkUniqueIds() {
    final seen = <String, ({String id, String name, int line})>{};
    for (final b in _written) {
      final first = seen[b.id];
      if (first != null) {
        _error(
          b.line,
          '${b.name} uses the id ${b.id}, which ${first.name} on line ${first.line} already uses. '
          'Each id must be unique.',
        );
      } else {
        seen[b.id] = b;
      }
    }
  }

  void _checkReferences(List<BlockDef> blocks, List<String>? dayTypes) {
    final ids = {for (final b in _written) b.id};
    for (final b in blocks) {
      final target = b.rightAfter;
      if (target != null) {
        if (target == b.id) {
          _error(b.line, '${b.name} says right_after: $target, which is itself.');
        } else if (!ids.contains(target)) {
          _error(
            b.line,
            "${b.name} says right_after: $target, but there's no block with id $target.",
            suggestion: _closestBlock(target),
          );
        }
      }
      if (dayTypes != null) {
        for (final (key, values) in [('only_on', b.onlyOn), ('skip_on', b.skipOn)]) {
          for (final v in values) {
            if (dayTypes.contains(v)) continue;
            _error(
              b.line,
              "${b.name} says $key: $v, but $v isn't one of your day_types (${dayTypes.join(', ')}).",
              suggestion: closestMatch(v, dayTypes),
            );
          }
        }
      }
    }
  }

  /// Closest block id, comparing against both ids and names. Returns the id.
  String? _closestBlock(String target) {
    final byCandidate = <String, String>{};
    for (final b in _written) {
      byCandidate[b.id] = b.id;
      byCandidate.putIfAbsent(b.name, () => b.id);
    }
    final match = closestMatch(target, byCandidate.keys.toList());
    return match == null ? null : byCandidate[match];
  }

  void _checkPinned(List<BlockDef> blocks, ClockTime bedtime) {
    BlockDef? previous;
    for (final b in blocks.where((b) => b.isPinned)) {
      final start = b.at!.dayMinutes;
      final end = start + b.minutes;
      if (previous != null) {
        final prevStart = previous.at!.dayMinutes;
        final prevEnd = prevStart + previous.minutes;
        if (start < prevStart) {
          _error(
            b.line,
            '${b.name} is pinned to ${b.at} but comes after ${previous.name} at ${previous.at}. '
            'Pinned blocks must be in clock order.',
          );
        } else if (start < prevEnd) {
          _error(
            b.line,
            '${b.name} starts at ${b.at}, but ${previous.name} runs until ${_fmtDayMinutes(prevEnd)}. '
            "Pinned blocks can't overlap.",
          );
        }
      }
      if (end > bedtime.dayMinutes) {
        _error(
          b.line,
          '${b.name} runs until ${_fmtDayMinutes(end)}, after bedtime at $bedtime. '
          'Pinned blocks must end by bedtime.',
        );
      }
      previous = b;
    }
  }

  String _fmtDayMinutes(int m) {
    final wrapped = m % (24 * 60);
    return ClockTime(wrapped ~/ 60, wrapped % 60).toString();
  }

  String _show(Object? value) {
    if (value == null) return 'empty';
    if (value is String) return '"$value"';
    if (value is YamlList || value is List) return 'a list';
    if (value is YamlMap || value is Map) return 'a group of fields';
    return value.toString();
  }
}

/// Returns the candidate closest to [target] by edit distance (ignoring case),
/// or null if none is close enough to be a likely typo.
String? closestMatch(String target, Iterable<String> candidates) {
  final t = target.toLowerCase();
  if (t.isEmpty) return null;
  final allowed = t.length <= 4 ? 1 : (t.length <= 8 ? 2 : 3);
  String? best;
  var bestDistance = allowed + 1;
  for (final c in candidates) {
    final d = editDistance(t, c.toLowerCase());
    if (d < bestDistance && d < c.length) {
      best = c;
      bestDistance = d;
    }
  }
  return best;
}

/// Optimal string alignment distance: insertions, deletions, substitutions
/// and swaps of two adjacent letters each cost 1.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final rows = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    rows[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    rows[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = [
        rows[i - 1][j] + 1,
        rows[i][j - 1] + 1,
        rows[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final swap = rows[i - 2][j - 2] + 1;
        if (swap < v) v = swap;
      }
      rows[i][j] = v;
    }
  }
  return rows[a.length][b.length];
}
