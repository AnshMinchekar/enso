/// JSON for the parts of a day that are saved between launches. Pure Dart.
///
/// A plan is not stored block by block: it is rebuilt from the schedule and
/// the saved [DayInput] (which holds every finished, extended or skipped
/// block), and the cuts that applied to finished blocks are restored with it.
library;

import 'models.dart';
import 'planner.dart';

const int kDayFormat = 1;

Map<String, Object?> dayInputToJson(DayInput d) => {
  'wake': d.wake.toIso8601String(),
  'dayTypes': d.dayTypes.toList()..sort(),
  'errands': [
    for (final e in d.errands) {'name': e.name, 'minutes': e.minutes},
  ],
  'bedtimeOverride': d.bedtimeOverride?.toString(),
  'now': d.now?.toIso8601String(),
  'locked': [
    for (final l in d.locked)
      {'id': l.blockId, 'start': l.start.toIso8601String(), 'end': l.end.toIso8601String()},
  ],
  'removed': d.removed.toList()..sort(),
};

DayInput dayInputFromJson(Map<String, Object?> j) => DayInput(
  wake: DateTime.parse(j['wake']! as String),
  dayTypes: {for (final t in j['dayTypes']! as List) t as String},
  errands: [
    for (final e in j['errands']! as List)
      Errand((e as Map)['name'] as String, e['minutes'] as int),
  ],
  bedtimeOverride: j['bedtimeOverride'] == null
      ? null
      : ClockTime.tryParse(j['bedtimeOverride']! as String),
  now: j['now'] == null ? null : DateTime.parse(j['now']! as String),
  locked: [
    for (final l in j['locked']! as List)
      LockedBlock(
        (l as Map)['id'] as String,
        DateTime.parse(l['start'] as String),
        DateTime.parse(l['end'] as String),
      ),
  ],
  removed: {for (final r in j['removed']! as List) r as String},
);

Map<String, Object?> cutToJson(Cut c) => {
  'id': c.blockId,
  'from': c.fromMinutes,
  'to': c.toMinutes,
  'dropped': c.dropped,
};

Cut cutFromJson(Map<String, Object?> j) => Cut(
  blockId: j['id']! as String,
  fromMinutes: j['from']! as int,
  toMinutes: j['to']! as int,
  dropped: j['dropped']! as bool,
);

/// Everything needed to restore today: the input and the cuts on show.
Map<String, Object?> planToJson(Plan p) => {
  'format': kDayFormat,
  'input': dayInputToJson(p.input),
  'cuts': [for (final c in p.cuts) cutToJson(c)],
};

/// Rebuilds a saved plan against [schedule]. Returns null if the data is
/// unreadable or from another format, so the app falls back to check-in
/// instead of guessing.
Plan? planFromJson(Map<String, Object?> j, Schedule schedule) {
  try {
    if (j['format'] != kDayFormat) return null;
    final input = dayInputFromJson((j['input']! as Map).cast<String, Object?>());
    final rebuilt = buildPlan(schedule, input);
    final cuts = [
      for (final c in j['cuts']! as List) cutFromJson((c as Map).cast<String, Object?>()),
    ];
    return Plan(
      schedule: rebuilt.schedule,
      input: rebuilt.input,
      blocks: rebuilt.blocks,
      bedtime: rebuilt.bedtime,
      cuts: List.unmodifiable(cuts),
      missed: rebuilt.missed,
      overflowMinutes: rebuilt.overflowMinutes,
    );
  } on Object {
    return null;
  }
}
