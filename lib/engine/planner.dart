/// Scheduling engine. Pure Dart, no Flutter imports.
///
/// Builds today's timeline from a [Schedule] and a [DayInput], re-plans after
/// block actions and previews what an action would change. See
/// `docs/specs.md` § 2.
library;

import 'models.dart';

/// Minutes between waking up and the first block.
const int wakeBufferMinutes = 5;

/// Builds the plan for one day. With [DayInput.now] set it re-plans: locked
/// blocks keep their times and the rest is planned from now.
Plan buildPlan(Schedule s, DayInput input) => _Planner(s, input).build();

/// Applies [action] at [now] and returns the re-planned day.
Plan applyAction(Plan current, PlanAction action, DateTime now) {
  final inProgress = current.blockAt(now);
  final locked = <LockedBlock>[];
  final removed = {...current.input.removed};

  switch (action) {
    case ExtendAction():
      if (inProgress == null || action.minutes <= 0) return current;
    case SkipAction(:final blockId) || DoneAction(:final blockId):
      final target = current.blockById(blockId);
      if (target == null || !target.end.isAfter(now)) return current;
    case RunningLateAction():
      break;
  }

  for (final b in current.blocks) {
    if (!b.start.isBefore(now)) continue;
    if (b == inProgress) {
      switch (action) {
        case ExtendAction(:final minutes):
          locked.add(LockedBlock(b.id, b.start, b.end.add(Duration(minutes: minutes))));
        case SkipAction(:final blockId) when blockId == b.id:
          removed.add(b.id);
        case DoneAction(:final blockId) when blockId == b.id:
          locked.add(LockedBlock(b.id, b.start, now));
        case RunningLateAction():
          // Not locked: it is planned again from now.
          break;
        default:
          locked.add(LockedBlock(b.id, b.start, b.end));
      }
    } else {
      locked.add(LockedBlock(b.id, b.start, b.end));
    }
  }

  switch (action) {
    case SkipAction(:final blockId) || DoneAction(:final blockId) when inProgress?.id != blockId:
      removed.add(blockId);
    default:
      break;
  }

  final next = buildPlan(
    current.schedule,
    current.input.copyWith(now: now, locked: locked, removed: removed),
  );

  // Cuts made earlier to blocks that are now locked still describe today.
  final lockedIds = {for (final l in locked) l.blockId};
  final keptCuts = current.cuts.where((c) => lockedIds.contains(c.blockId));
  return Plan(
    schedule: next.schedule,
    input: next.input,
    blocks: next.blocks,
    bedtime: next.bedtime,
    cuts: [...keptCuts, ...next.cuts.where((c) => !lockedIds.contains(c.blockId))],
    missed: next.missed,
    overflowMinutes: next.overflowMinutes,
  );
}

/// What [action] would change, without applying it.
List<PlanChange> previewAction(Plan current, PlanAction action, DateTime now) =>
    diffPlans(current, applyAction(current, action, now));

/// Differences between two plans of the same day, in time order. A block can
/// appear twice: once as moved and once as shortened or lengthened.
List<PlanChange> diffPlans(Plan before, Plan after) {
  final changes = <PlanChange>[];
  for (final old in before.blocks) {
    final now = after.blockById(old.id);
    if (now == null) {
      changes.add(
        PlanChange(
          kind: PlanChangeKind.dropped,
          block: old.block,
          fromStart: old.start,
          fromMinutes: old.minutes,
          toMinutes: 0,
        ),
      );
      continue;
    }
    if (now.start != old.start) {
      changes.add(
        PlanChange(
          kind: PlanChangeKind.moved,
          block: old.block,
          fromStart: old.start,
          toStart: now.start,
        ),
      );
    }
    if (now.minutes != old.minutes) {
      changes.add(
        PlanChange(
          kind: now.minutes < old.minutes ? PlanChangeKind.shortened : PlanChangeKind.lengthened,
          block: old.block,
          fromStart: old.start,
          toStart: now.start,
          fromMinutes: old.minutes,
          toMinutes: now.minutes,
        ),
      );
    }
  }
  for (final b in after.blocks) {
    if (before.blockById(b.id) == null) {
      changes.add(
        PlanChange(
          kind: PlanChangeKind.added,
          block: b.block,
          toStart: b.start,
          fromMinutes: 0,
          toMinutes: b.minutes,
        ),
      );
    }
  }
  changes.sort((a, b) => (a.toStart ?? a.fromStart!).compareTo(b.toStart ?? b.fromStart!));
  return changes;
}

/// One plain sentence for the block sheet, for example
/// "With +15 min, Lunch moves to 12:45 and Walk becomes 15 min."
///
/// [subjectId] is the block the action is about; its own change is left out.
/// Mentions the next block that moves and up to two blocks that get shorter
/// or are dropped. Returns null when nothing else changes.
String? describePreview(PlanAction action, List<PlanChange> changes, {String? subjectId}) {
  final others = changes.where((c) => c.block.id != subjectId).toList();
  final parts = <String>[];

  final firstMove = others.where((c) => c.kind == PlanChangeKind.moved).firstOrNull;
  if (firstMove != null) {
    parts.add('${firstMove.block.name} moves to ${formatClock(firstMove.toStart!)}');
  }
  final smaller = others.where(
    (c) => c.kind == PlanChangeKind.shortened || c.kind == PlanChangeKind.dropped,
  );
  for (final c in smaller.take(2)) {
    parts.add(
      c.kind == PlanChangeKind.dropped || c.toMinutes == 0
          ? '${c.block.name} is left out'
          : '${c.block.name} becomes ${formatDuration(c.toMinutes!)}',
    );
  }
  if (parts.isEmpty) {
    final grown = others.where((c) => c.kind == PlanChangeKind.lengthened).firstOrNull;
    if (grown != null) parts.add('${grown.block.name} becomes ${formatDuration(grown.toMinutes!)}');
  }
  if (parts.isEmpty) return null;

  final lead = switch (action) {
    ExtendAction(:final minutes) => 'With +$minutes min',
    SkipAction() => 'If you skip it',
    DoneAction() => 'If you finish now',
    RunningLateAction() => 'Starting from now',
  };
  final body = parts.length == 1
      ? parts.single
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  return '$lead, $body.';
}

/// "45 min", "1h", "1h 15", matching the mockups.
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}';
}

/// "HH:MM".
String formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// -----------------------------------------------------------------------------

/// A block being sized within a segment.
class _Item {
  _Item(this.def) : minutes = def.minutes;

  final BlockDef def;
  int minutes;
}

class _SegmentResult {
  final List<PlannedBlock> placed = [];
  final List<Cut> cuts = [];
  int overflow = 0;
}

class _Planner {
  _Planner(this.schedule, this.input);

  final Schedule schedule;
  final DayInput input;

  late final DateTime _dayStart = _appDayStart(input.wake);

  /// Midnight at the start of the app day the wake time belongs to. Before
  /// 04:00 counts as the previous day.
  static DateTime _appDayStart(DateTime wake) {
    final midnight = DateTime(wake.year, wake.month, wake.day);
    return wake.hour < ClockTime.dayStartHour
        ? DateTime(midnight.year, midnight.month, midnight.day - 1)
        : midnight;
  }

  DateTime _at(ClockTime c) =>
      DateTime(_dayStart.year, _dayStart.month, _dayStart.day, 0, c.dayMinutes);

  Plan build() {
    final bedtime = _at(input.bedtimeOverride ?? schedule.bedtime);
    final ordered = _orderedBlocks();

    final lockedById = {for (final l in input.locked) l.blockId: l};
    final placed = <PlannedBlock>[];
    final cuts = <Cut>[];
    final missed = <BlockDef>[];
    var overflow = 0;

    for (final def in ordered) {
      final l = lockedById[def.id];
      if (l != null) placed.add(PlannedBlock(def, l.start, l.end));
    }

    var start = input.wake.add(const Duration(minutes: wakeBufferMinutes));
    final now = input.now;
    if (now != null && now.isAfter(start)) start = now;
    for (final l in input.locked) {
      if (l.end.isAfter(start)) start = l.end;
    }

    final remaining = ordered.where((d) => !lockedById.containsKey(d.id)).toList();

    // Split into segments around pinned blocks.
    var segmentStart = start;
    var items = <BlockDef>[];
    void closeSegment(DateTime end) {
      if (!end.isAfter(start) || !end.isAfter(segmentStart)) {
        missed.addAll(items);
      } else {
        final from = segmentStart.isAfter(start) ? segmentStart : start;
        final r = _planSegment(items, from, end);
        placed.addAll(r.placed);
        cuts.addAll(r.cuts);
        overflow += r.overflow;
      }
      items = [];
    }

    for (final def in remaining) {
      if (!def.isPinned) {
        items.add(def);
        continue;
      }
      final pinStart = _at(def.at!);
      final pinEnd = pinStart.add(Duration(minutes: def.minutes));
      closeSegment(pinStart);
      if (!pinEnd.isAfter(start)) {
        missed.add(def);
      } else if (pinStart.isBefore(start)) {
        // Woke after it started: start now, keep the original end.
        placed.add(PlannedBlock(def, start, pinEnd));
        cuts.add(
          Cut(
            blockId: def.id,
            fromMinutes: def.minutes,
            toMinutes: pinEnd.difference(start).inMinutes,
          ),
        );
      } else {
        placed.add(PlannedBlock(def, pinStart, pinEnd));
      }
      segmentStart = pinEnd;
    }
    closeSegment(bedtime);

    placed.sort((a, b) => a.start.compareTo(b.start));
    return Plan(
      schedule: schedule,
      input: input,
      blocks: List.unmodifiable(placed),
      bedtime: bedtime,
      cuts: List.unmodifiable(cuts),
      missed: List.unmodifiable(missed),
      overflowMinutes: overflow,
    );
  }

  /// Steps 1 to 3: filter by day type, insert errands, apply right_after.
  List<BlockDef> _orderedBlocks() {
    final types = input.dayTypes;
    final list = schedule.blocks.where((b) {
      if (input.removed.contains(b.id)) return false;
      if (b.onlyOn.isNotEmpty && !b.onlyOn.any(types.contains)) return false;
      if (b.skipOn.any(types.contains)) return false;
      return true;
    }).toList();

    final errands = <BlockDef>[
      for (var i = 0; i < input.errands.length; i++)
        BlockDef(
          id: 'errand_${i + 1}',
          name: input.errands[i].name,
          minutes: input.errands[i].minutes,
          category: Category.errand,
        ),
    ].where((e) => !input.removed.contains(e.id)).toList();

    if (errands.isNotEmpty) {
      final free = list.indexWhere((b) => b.category == Category.rest && b.min == 0);
      if (free >= 0) {
        list.replaceRange(free, free + 1, errands);
      } else {
        final lunch = list.indexWhere((b) => b.id == 'lunch');
        final at = lunch >= 0 ? lunch + 1 : (list.isEmpty ? 0 : list.length - 1);
        list.insertAll(at, errands);
      }
    }

    for (final b in schedule.blocks) {
      final target = b.rightAfter;
      if (target == null || b.isPinned) continue;
      final from = list.indexWhere((x) => x.id == b.id);
      if (from < 0 || !list.any((x) => x.id == target)) continue;
      final moving = list.removeAt(from);
      final to = list.indexWhere((x) => x.id == target);
      list.insert(to + 1, moving);
    }
    return list;
  }

  /// Steps 4 to 9 for one segment.
  _SegmentResult _planSegment(List<BlockDef> defs, DateTime from, DateTime to) {
    final available = to.difference(from).inMinutes;
    final lateDropped = <BlockDef>[];

    while (true) {
      final result = _SegmentResult();
      final items = [
        for (final d in defs)
          if (!lateDropped.contains(d)) _Item(d),
      ];
      for (final d in lateDropped) {
        result.cuts.add(Cut(blockId: d.id, fromMinutes: d.minutes, toMinutes: 0, dropped: true));
      }

      int total() => items.fold(0, (sum, i) => sum + i.minutes);

      // Step 5: shorten the highest priority number first, later block on ties.
      while (total() > available) {
        _Item? pick;
        for (final i in items) {
          if (!i.def.isShrinkable || i.minutes <= i.def.min!) continue;
          if (pick == null || i.def.priority! >= pick.def.priority!) pick = i;
        }
        if (pick == null) break;
        final over = total() - available;
        final room = pick.minutes - pick.def.min!;
        pick.minutes -= over < room ? over : room;
      }

      // Step 6: blocks squeezed to nothing are dropped.
      for (final i in items) {
        if (i.minutes != i.def.minutes) {
          result.cuts.add(
            Cut(
              blockId: i.def.id,
              fromMinutes: i.def.minutes,
              toMinutes: i.minutes,
              dropped: i.minutes == 0,
            ),
          );
        }
      }
      items.removeWhere((i) => i.minutes == 0);
      result.overflow = total() > available ? total() - available : 0;

      // Step 7: spare time goes to the last free block, else the last
      // shrinkable one. With neither, the gap stays at the end.
      final spare = available - total();
      if (spare > 0) {
        final free = items.lastWhere((i) => i.def.min == 0, orElse: () => _none);
        final target = free != _none
            ? free
            : items.lastWhere((i) => i.def.isShrinkable, orElse: () => _none);
        if (target != _none) target.minutes += spare;
      }

      // Step 8: assign times.
      var t = from;
      for (final i in items) {
        final end = t.add(Duration(minutes: i.minutes));
        result.placed.add(PlannedBlock(i.def, t, end));
        t = end;
      }

      // Step 9: drop the first block that starts after its latest_start.
      final late = result.placed
          .where((p) => p.block.latestStart != null && p.start.isAfter(_at(p.block.latestStart!)))
          .firstOrNull;
      if (late == null) return result;
      lateDropped.add(late.block);
    }
  }

  static final _Item _none = _Item(const BlockDef(id: '', name: '', minutes: 0));
}
