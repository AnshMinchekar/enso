/// Which notifications a plan needs. Pure Dart: the plugin glue lives in
/// `notifications.dart`.
library;

import '../engine/models.dart';
import '../engine/planner.dart' show formatClock;

/// Action ids on block-change notifications.
const String kActionStart = 'start';
const String kActionPlusTen = 'plus10';

enum ReminderKind { blockStart, headsUp }

/// One notification to schedule.
class Reminder {
  const Reminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.blockId,
  });

  /// Stable per plan: 1000 + block index for starts, 2000 + index for
  /// heads-ups.
  final int id;
  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;
  final String blockId;

  /// Block changes carry Start and +10 min.
  bool get hasActions => kind == ReminderKind.blockStart;

  @override
  String toString() => 'Reminder($id ${kind.name} ${formatClock(at)} "$title" "$body")';
}

/// Notifications for the rest of [plan] after [now]:
///
/// - one at each block start (skipping blocks with `notify: false`):
///   "Enso · now" / "Career block, until 12:30. Next, Lunch."
/// - a heads-up [headsUpMinutes] before each block ends:
///   "Enso · 09:10" / "5 minutes left in Gym. Shower + snack next."
///
/// Heads-ups are skipped for blocks shorter than the heads-up, and for
/// blocks with `notify: false`.
List<Reminder> remindersFor(Plan plan, DateTime now, {required int headsUpMinutes}) {
  final out = <Reminder>[];
  final blocks = plan.blocks;
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    if (!b.block.notify) continue;
    final nextName = i + 1 < blocks.length ? blocks[i + 1].block.name : 'Lights out';

    if (b.start.isAfter(now)) {
      out.add(
        Reminder(
          id: 1000 + i,
          kind: ReminderKind.blockStart,
          at: b.start,
          title: 'Enso · now',
          body: '${b.block.name}, until ${formatClock(b.end)}. Next, $nextName.',
          blockId: b.id,
        ),
      );
    }

    final headsUp = b.end.subtract(Duration(minutes: headsUpMinutes));
    if (headsUpMinutes > 0 && b.minutes > headsUpMinutes && headsUp.isAfter(now)) {
      final minutes = headsUpMinutes == 1 ? '1 minute' : '$headsUpMinutes minutes';
      out.add(
        Reminder(
          id: 2000 + i,
          kind: ReminderKind.headsUp,
          at: headsUp,
          title: 'Enso · ${formatClock(headsUp)}',
          body: '$minutes left in ${b.block.name}. $nextName next.',
          blockId: b.id,
        ),
      );
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
