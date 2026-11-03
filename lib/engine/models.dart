/// Schedule file models. Pure Dart, no Flutter imports.
library;

/// A wall-clock time written as `"HH:MM"` in a schedule file.
///
/// Enso's day starts at 04:00 (the start of the morning period). Times from
/// 00:00 to 03:59 belong to the end of the day, so [dayMinutes] puts them after
/// 23:59. A bedtime of "00:30" is therefore later than a block `at: "23:00"`.
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// Hour at which the app's day begins. Earlier times count as after midnight.
  static const int dayStartHour = 4;

  static final RegExp _pattern = RegExp(r'^(\d{1,2}):(\d{2})$');

  /// Parses `"HH:MM"` (24-hour). Returns null for anything else.
  static ClockTime? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h > 23 || m > 59) return null;
    return ClockTime(h, m);
  }

  /// Minutes since midnight, 0 to 1439.
  int get minutesOfDay => hour * 60 + minute;

  /// Minutes since midnight on the app's day, where 00:00–03:59 count as
  /// 1440–1679. Use this to order and compare times within one day.
  int get dayMinutes => hour < dayStartHour ? minutesOfDay + 24 * 60 : minutesOfDay;

  ClockTime addMinutes(int minutes) {
    final total = (minutesOfDay + minutes) % (24 * 60);
    final wrapped = total < 0 ? total + 24 * 60 : total;
    return ClockTime(wrapped ~/ 60, wrapped % 60);
  }

  @override
  int compareTo(ClockTime other) => dayMinutes.compareTo(other.dayMinutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  /// Formats as `"HH:MM"`.
  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Block type. Drives the colour tint.
enum Category {
  focus,
  body,
  food,
  rest,
  leisure,

  /// Reserved for errands added at check-in. Not allowed in schedule files.
  errand;

  /// Categories a schedule file may use.
  static const List<Category> fileValues = [focus, body, food, rest, leisure];

  static Category? tryParse(String text) {
    for (final c in values) {
      if (c.name == text) return c;
    }
    return null;
  }
}

/// One block definition from the schedule file.
class BlockDef {
  const BlockDef({
    required this.id,
    required this.name,
    required this.minutes,
    this.detail,
    this.min,
    this.priority,
    this.onlyOn = const {},
    this.skipOn = const {},
    this.rightAfter,
    this.latestStart,
    this.at,
    this.category,
    this.notify = true,
    this.line = 0,
  });

  final String id;
  final String name;
  final String? detail;

  /// Normal length in minutes.
  final int minutes;

  /// Shortest length the engine may squeeze this block to. Null means the
  /// block is never shortened.
  final int? min;

  /// 1 is cut last, 9 is cut first. Present whenever [min] is.
  final int? priority;

  /// Block exists only when one of these day types is selected. Empty means
  /// no restriction.
  final Set<String> onlyOn;

  /// Block is removed when one of these day types is selected.
  final Set<String> skipOn;

  /// Id of the block this one moves directly after, when both exist.
  final String? rightAfter;

  /// Drop the block if it would start later than this.
  final ClockTime? latestStart;

  /// Pins the block to a fixed clock time.
  final ClockTime? at;

  final Category? category;

  /// False means no notification for this block.
  final bool notify;

  /// 1-based line in the source file where this block is defined. 0 for
  /// blocks that did not come from a file, such as errands.
  final int line;

  /// True when the engine may shorten this block.
  bool get isShrinkable => min != null;

  /// True when the block is pinned to a clock time.
  bool get isPinned => at != null;

  BlockDef copyWith({int? minutes, Category? category}) => BlockDef(
    id: id,
    name: name,
    minutes: minutes ?? this.minutes,
    detail: detail,
    min: min,
    priority: priority,
    onlyOn: onlyOn,
    skipOn: skipOn,
    rightAfter: rightAfter,
    latestStart: latestStart,
    at: at,
    category: category ?? this.category,
    notify: notify,
    line: line,
  );

  @override
  String toString() => 'BlockDef($id, $minutes min)';
}

/// A parsed schedule file.
class Schedule {
  const Schedule({
    required this.bedtime,
    required this.wakeTarget,
    required this.dayTypes,
    required this.blocks,
  });

  /// The time the day must end.
  final ClockTime bedtime;

  /// Intended wake time. Defaults to [bedtime] minus 8 hours.
  final ClockTime wakeTarget;

  /// Toggles shown at check-in, in file order.
  final List<String> dayTypes;

  /// Block definitions in file order.
  final List<BlockDef> blocks;

  BlockDef? blockById(String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// What kind of problem a [ScheduleError] describes.
enum ScheduleErrorKind {
  /// The text has no ```` ```routine ```` block at all. The paste flow shows
  /// the calm "no Enso schedule in this text" state for this.
  noRoutineBlock,

  /// Anything else: bad YAML, missing fields, broken references and so on.
  invalid,
}

/// A problem found while parsing a schedule file.
class ScheduleError {
  const ScheduleError({
    required this.line,
    required this.message,
    this.suggestion,
    this.kind = ScheduleErrorKind.invalid,
  });

  /// 1-based line number in the original `.md` file.
  final int line;

  /// Plain, specific sentence describing the problem.
  final String message;

  /// Closest existing id or name, shown as "Did you mean ...?". Null when
  /// nothing is close.
  final String? suggestion;

  final ScheduleErrorKind kind;

  @override
  String toString() =>
      'line $line: $message${suggestion == null ? '' : ' (did you mean $suggestion?)'}';
}

/// Result of parsing a schedule file. [schedule] is non-null only when
/// [errors] is empty.
class ParseResult {
  const ParseResult({this.schedule, this.errors = const []});

  final Schedule? schedule;
  final List<ScheduleError> errors;

  bool get isValid => schedule != null && errors.isEmpty;

  /// True when the text contains no `routine` block at all.
  bool get hasNoRoutineBlock => errors.any((e) => e.kind == ScheduleErrorKind.noRoutineBlock);
}
