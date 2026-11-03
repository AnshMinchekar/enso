/// Plain-language summary of a schedule for the schedule file screen and
/// the paste result: one line per block and a short list of rules.
library;

import '../engine/models.dart';
import 'format.dart';

/// "a, b or c".
String _joinOr(Iterable<String> items) {
  final l = items.toList();
  if (l.length <= 1) return l.join();
  return '${l.sublist(0, l.length - 1).join(', ')} or ${l.last}';
}

/// "a, b and c", or "a, b, c and 4 more" past [max] names.
String _joinAnd(Iterable<String> items, {int max = 3}) {
  final l = items.toList();
  if (l.length <= 1) return l.join();
  if (l.length > max) return '${l.take(max).join(', ')} and ${l.length - max} more';
  return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
}

List<String> _uniqueNames(Iterable<BlockDef> blocks) => {for (final b in blocks) b.name}.toList();

/// Length and rule for one block, for example "1h 45 · gym days",
/// "2h 45 · min 1h 30", "25 min · fixed".
String blockLengthLabel(BlockDef b) {
  final length = formatDuration(b.minutes);
  final min = b.min;
  final String rule;
  if (b.onlyOn.isNotEmpty) {
    rule = '${_joinOr(b.onlyOn)} days';
  } else if (b.at != null) {
    rule = 'at ${b.at}';
  } else if (min == null) {
    rule = 'fixed';
  } else if (min == 0) {
    rule = 'can drop';
  } else {
    rule = 'min ${formatDuration(min)}';
  }
  return '$length · $rule';
}

/// The schedule's rules as short sentences, in a fixed order.
List<String> scheduleRules(Schedule s) {
  final rules = <String>['Lights out is ${s.bedtime} and never moves.'];
  final blocks = s.blocks;

  for (final b in blocks.where((b) => b.at != null)) {
    rules.add('${b.name} is fixed at ${b.at}.');
  }

  final fixed = _uniqueNames(blocks.where((b) => b.min == null && b.at == null));
  if (fixed.isNotEmpty) {
    rules.add('${_joinAnd(fixed)} ${fixed.length == 1 ? 'is' : 'are'} never shortened.');
  }

  // Cut order: highest priority number first, the later block on ties.
  final shrinkable =
      [
        for (var i = 0; i < blocks.length; i++)
          if (blocks[i].min != null && blocks[i].min! > 0) (i, blocks[i]),
      ]..sort((a, b) {
        final p = b.$2.priority!.compareTo(a.$2.priority!);
        return p != 0 ? p : b.$1.compareTo(a.$1);
      });
  final hasFree = blocks.any((b) => b.min == 0);
  final order = _uniqueNames(shrinkable.map((e) => e.$2)).take(3).toList();
  if (hasFree || order.isNotEmpty) {
    final steps = [if (hasFree) 'free time goes first', ...order];
    final buffer = StringBuffer('When the day is full, ');
    if (hasFree) {
      buffer.write(steps.first);
      for (final n in steps.skip(1)) {
        buffer.write(', then $n');
      }
    } else {
      buffer.write('shorten ${order.first} first');
      for (final n in order.skip(1)) {
        buffer.write(', then $n');
      }
    }
    buffer.write('.');
    rules.add(buffer.toString());
  }

  final byOnlyOn = <String, List<BlockDef>>{};
  for (final b in blocks.where((b) => b.onlyOn.isNotEmpty)) {
    byOnlyOn.putIfAbsent(_joinOr(b.onlyOn), () => []).add(b);
  }
  byOnlyOn.forEach((days, list) {
    final names = _uniqueNames(list);
    rules.add('${_joinAnd(names)} only ${names.length == 1 ? 'appears' : 'appear'} on $days days.');
  });

  for (final b in blocks.where((b) => b.skipOn.isNotEmpty)) {
    rules.add('${b.name} is left out on ${_joinOr(b.skipOn)} days.');
  }

  for (final b in blocks.where((b) => b.rightAfter != null)) {
    final target = s.blockById(b.rightAfter!);
    if (target != null) rules.add('${b.name} comes right after ${target.name}.');
  }

  for (final b in blocks.where((b) => b.latestStart != null)) {
    rules.add('${b.name} is dropped if it would start after ${b.latestStart}.');
  }
  return rules;
}

/// "8 blocks · 4 rules".
String scheduleCounts(Schedule s) {
  final n = s.blocks.length;
  final r = scheduleRules(s).length;
  return '$n ${n == 1 ? 'block' : 'blocks'} · $r ${r == 1 ? 'rule' : 'rules'}';
}

/// Rough block count of text that didn't parse, for "8 blocks · 3 lines
/// need a fix".
int countBlockLines(String text) =>
    RegExp(r'^\s*-\s*(\{|id\s*:)', multiLine: true).allMatches(text).length;

/// "Running since 24 Oct".
String sinceLabel(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

/// "Did you mean Cook?" style suggestion, capitalised like a name when the
/// suggestion is a block's id.
String? suggestionLine(ScheduleError e) =>
    e.suggestion == null ? null : 'Did you mean ${e.suggestion}?';

/// Kept for the error card overline: "Line 42".
String lineLabel(ScheduleError e) => 'Line ${e.line}';
