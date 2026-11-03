import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:enso/engine/planner.dart';
import 'package:flutter_test/flutter_test.dart';

Schedule load(String name) =>
    parseSchedule(File('test/fixtures/$name').readAsStringSync()).schedule!;

/// 26 October 2026, a Monday, at [hm].
DateTime at(String hm, {int day = 26}) {
  final t = ClockTime.tryParse(hm)!;
  return DateTime(2026, 10, day, t.hour, t.minute);
}

String hm(DateTime t) => formatClock(t);

List<String> ids(Plan p) => p.blocks.map((b) => b.id).toList();

/// Asserts blocks are back to back or have gaps, never overlap, and stay in order.
void expectNoOverlap(Plan p) {
  for (var i = 1; i < p.blocks.length; i++) {
    expect(
      p.blocks[i].start.isBefore(p.blocks[i - 1].end),
      isFalse,
      reason: '${p.blocks[i - 1]} overlaps ${p.blocks[i]}',
    );
  }
}

void main() {
  final sample = load('sample.md');
  final workday = load('workday.md');

  group('sample.md', () {
    test('wake 06:15, gym: fits, no cuts, last block ends 22:30', () {
      final p = buildPlan(sample, DayInput(wake: at('06:15'), dayTypes: {'gym'}));
      expect(p.cuts, isEmpty);
      expect(p.overflowMinutes, 0);
      expect(p.blocks.first.start, at('06:20'));
      expect(p.blocks.last.id, 'winddown');
      expect(p.blocks.last.end, at('22:30'));
      expect(ids(p), isNot(contains('cook')));
      expect(ids(p), containsAll(['preworkout', 'gym']));
      expectNoOverlap(p);
      // 15 spare minutes go to the last free block.
      expect(p.blockById('free2')!.minutes, 100);
    });

    test('wake 07:55, gym + cook: lunch after cook, free first, side_project before deep_work', () {
      final p = buildPlan(sample, DayInput(wake: at('07:55'), dayTypes: {'gym', 'cook'}));
      final order = ids(p);
      expect(order.indexOf('lunch'), order.indexOf('cook') + 1);
      expect(p.blockById('lunch')!.start, p.blockById('cook')!.end);

      final cutIds = p.cuts.map((c) => c.blockId).toList();
      expect(cutIds, containsAll(['free1', 'free2']));
      expect(p.cutFor('free1')!.dropped, isTrue);
      expect(p.cutFor('free2')!.dropped, isTrue);
      expect(p.cutFor('side_project'), isNotNull);
      expect(p.cutFor('deep_work'), isNull, reason: 'side_project is cut before deep_work');
      expect(p.blockById('deep_work')!.minutes, greaterThanOrEqualTo(105));
      expect(p.blocks.last.end, at('22:30'));
      expect(p.overflowMinutes, 0);
      expectNoOverlap(p);
    });

    test('wake 10:00, gym: ends by 22:30, all meals present, cuts listed', () {
      final p = buildPlan(sample, DayInput(wake: at('10:00'), dayTypes: {'gym'}));
      expect(p.blocks.last.end.isAfter(at('22:30')), isFalse);
      for (final meal in ['breakfast', 'lunch', 'shower', 'snack', 'dinner', 'late_snack']) {
        expect(p.blockById(meal), isNotNull, reason: meal);
        expect(p.blockById(meal)!.minutes, sample.blockById(meal)!.minutes, reason: meal);
      }
      expect(p.cuts, isNotEmpty);
      for (final c in p.cuts) {
        final def = sample.blockById(c.blockId)!;
        expect(def.isShrinkable, isTrue, reason: '${c.blockId} has no min');
        expect(c.toMinutes, greaterThanOrEqualTo(def.min!));
      }
      expect(p.overflowMinutes, 0);
      expectNoOverlap(p);
    });

    test('wake 13:30, gym: preworkout is dropped (latest_start 14:00)', () {
      final p = buildPlan(sample, DayInput(wake: at('13:30'), dayTypes: {'gym'}));
      expect(p.blockById('preworkout'), isNull);
      final cut = p.cutFor('preworkout')!;
      expect(cut.dropped, isTrue);
      expect(cut.toMinutes, 0);
      expect(p.blockById('gym'), isNotNull);
      // Nothing without a min is ever shortened, even when the day overflows.
      for (final b in p.blocks.where((b) => !b.block.isShrinkable)) {
        expect(b.minutes, b.block.minutes, reason: b.id);
      }
      expect(p.overflowMinutes, greaterThan(0));
    });

    test('rest day: gym and preworkout absent, spare time goes to free time', () {
      final p = buildPlan(sample, DayInput(wake: at('06:15'), dayTypes: {'rest'}));
      expect(ids(p), isNot(contains('gym')));
      expect(ids(p), isNot(contains('preworkout')));
      expect(p.cuts, isEmpty);
      // 970 available, 820 planned: 150 spare on top of free2's 85.
      expect(p.blockById('free2')!.minutes, 85 + 150);
      expect(p.blockById('free1')!.minutes, 45);
      expect(p.blocks.last.end, at('22:30'));
    });

    test('errand on a normal day takes the first free block\'s place', () {
      final p = buildPlan(
        sample,
        DayInput(wake: at('06:15'), dayTypes: {'gym'}, errands: const [Errand('Haircut', 60)]),
      );
      final order = ids(p);
      expect(order, isNot(contains('free1')));
      expect(order[order.indexOf('deep_work') + 1], 'errand_1');
      expect(order[order.indexOf('errand_1') + 1], 'side_project');
      final errand = p.blockById('errand_1')!;
      expect(errand.block.category, Category.errand);
      expect(errand.block.name, 'Haircut');
      expect(errand.minutes, 60);
      expect(p.blocks.last.end, at('22:30'));
    });

    test('errand with no free block goes after lunch', () {
      final noFree = Schedule(
        bedtime: sample.bedtime,
        wakeTarget: sample.wakeTarget,
        dayTypes: sample.dayTypes,
        blocks: sample.blocks.where((b) => b.min != 0).toList(),
      );
      final p = buildPlan(
        noFree,
        DayInput(wake: at('06:15'), dayTypes: {'gym'}, errands: const [Errand('Post office', 20)]),
      );
      final order = ids(p);
      expect(order[order.indexOf('lunch') + 1], 'errand_1');
    });

    test('re-plan at 12:00 with +30 min on the current block', () {
      final before = buildPlan(sample, DayInput(wake: at('06:15'), dayTypes: {'gym'}));
      final now = at('12:00');
      final current = before.blockAt(now)!;
      expect(current.id, 'deep_work');

      final after = applyAction(before, const ExtendAction(30), now);

      // Earlier blocks keep their times.
      for (final b in before.blocks.where((b) => b.end.isBefore(now))) {
        expect(after.blockById(b.id)!.start, b.start, reason: b.id);
        expect(after.blockById(b.id)!.end, b.end, reason: b.id);
      }
      // The current block is 30 minutes longer.
      expect(after.blockById('deep_work')!.start, current.start);
      expect(after.blockById('deep_work')!.end, current.end.add(const Duration(minutes: 30)));
      // The next blocks shift by 30 minutes.
      for (final id in ['free1', 'side_project', 'snack', 'free2']) {
        expect(
          after.blockById(id)!.start,
          before.blockById(id)!.start.add(const Duration(minutes: 30)),
          reason: id,
        );
      }
      // Cuts recomputed: 15 spare minutes are gone and free2 loses 15 more.
      expect(before.cuts, isEmpty);
      expect(after.cuts, [const Cut(blockId: 'free2', fromMinutes: 85, toMinutes: 70)]);
      expect(after.blocks.last.end, at('22:30'));
      expectNoOverlap(after);
    });

    test('re-planning is the same function with now set', () {
      final before = buildPlan(sample, DayInput(wake: at('06:15'), dayTypes: {'gym'}));
      final viaAction = applyAction(before, const ExtendAction(30), at('12:00'));
      final direct = buildPlan(sample, viaAction.input);
      expect(ids(direct), ids(viaAction));
      for (final b in direct.blocks) {
        expect(b.start, viaAction.blockById(b.id)!.start);
      }
    });

    test('preview of +15 min matches applying +15 min', () {
      final before = buildPlan(sample, DayInput(wake: at('06:15'), dayTypes: {'gym'}));
      final now = at('12:00');
      final preview = previewAction(before, const ExtendAction(15), now);
      final applied = applyAction(before, const ExtendAction(15), now);

      expect(preview, isNotEmpty);
      // The preview didn't touch the current plan.
      expect(before.blockById('deep_work')!.end, at('13:30'));

      final changed = <String>{};
      for (final c in preview) {
        changed.add(c.block.id);
        final b = applied.blockById(c.block.id);
        switch (c.kind) {
          case PlanChangeKind.moved:
            expect(b!.start, c.toStart);
          case PlanChangeKind.shortened || PlanChangeKind.lengthened:
            expect(b!.minutes, c.toMinutes);
          case PlanChangeKind.dropped:
            expect(b, isNull);
          case PlanChangeKind.added:
            expect(b, isNotNull);
        }
      }
      for (final b in before.blocks.where((b) => !changed.contains(b.id))) {
        expect(applied.blockById(b.id)!.start, b.start, reason: b.id);
        expect(applied.blockById(b.id)!.end, b.end, reason: b.id);
      }

      // +15 uses exactly the 15 spare minutes, so free2 shrinks back to 85.
      expect(
        describePreview(const ExtendAction(15), preview, subjectId: 'deep_work'),
        'With +15 min, Free moves to 13:45 and Free becomes 1h 25.',
      );
    });

    test('bedtime override of 23:00 gives 30 more minutes', () {
      final normal = buildPlan(sample, DayInput(wake: at('06:15'), dayTypes: {'gym'}));
      final late = buildPlan(
        sample,
        DayInput(wake: at('06:15'), dayTypes: {'gym'}, bedtimeOverride: const ClockTime(23, 0)),
      );
      int total(Plan p) => p.blocks.fold(0, (s, b) => s + b.minutes);
      expect(total(late), total(normal) + 30);
      expect(late.blocks.last.end, at('23:00'));
      expect(late.bedtime, at('23:00'));
    });
  });

  test('bedtime override can be changed and cleared mid-day', () {
    final input = DayInput(
      wake: at('06:15'),
      dayTypes: {'gym'},
      bedtimeOverride: const ClockTime(23, 0),
    );
    final cleared = buildPlan(sample, input.withBedtimeOverride(null));
    expect(cleared.bedtime, at('22:30'));
    final later = buildPlan(sample, input.withBedtimeOverride(const ClockTime(23, 30)));
    expect(later.blocks.last.end, at('23:30'));
    expect(input.withBedtimeOverride(null).dayTypes, {'gym'});
  });

  group('workday.md', () {
    test('wake 07:00: commute 08:30, work 09:00–17:00, no cuts', () {
      final p = buildPlan(workday, DayInput(wake: at('07:00'), dayTypes: {'rest'}));
      expect(hm(p.blockById('commute_in')!.start), '08:30');
      expect(hm(p.blockById('work')!.start), '09:00');
      expect(hm(p.blockById('work')!.end), '17:00');
      expect(p.cuts, isEmpty);
      expect(p.missed, isEmpty);
      expect(hm(p.blockById('breakfast')!.start), '07:05');
      expect(hm(p.blockById('commute_home')!.start), '17:00');
      expect(p.blocks.last.end, at('23:00'));
      expectNoOverlap(p);
    });

    test('wake 08:45: commute starts 08:50 and ends 09:00, breakfast missed', () {
      final p = buildPlan(workday, DayInput(wake: at('08:45'), dayTypes: {'rest'}));
      final commute = p.blockById('commute_in')!;
      expect(hm(commute.start), '08:50');
      expect(hm(commute.end), '09:00');
      expect(
        p.cutFor('commute_in'),
        const Cut(blockId: 'commute_in', fromMinutes: 30, toMinutes: 10),
      );
      expect(p.missed.map((b) => b.id), ['breakfast']);
      expect(p.blockById('breakfast'), isNull);
      expect(hm(p.blockById('work')!.start), '09:00');
      expect(hm(p.blockById('work')!.end), '17:00');
    });

    test('any wake time: evening fits by cutting free first, gym only after free is 0', () {
      for (final wake in ['05:30', '07:00', '08:00', '08:45', '10:30', '16:00']) {
        final p = buildPlan(workday, DayInput(wake: at(wake), dayTypes: {'gym'}));
        expect(p.overflowMinutes, 0, reason: wake);
        expect(p.blocks.last.end, at('23:00'), reason: wake);
        expect(p.blockById('work')!.end, at('17:00'), reason: wake);
        final gymCut = p.cutFor('gym');
        if (gymCut != null) {
          expect(p.blockById('free'), isNull, reason: 'free must be gone before gym shrinks');
        }
        expect(p.blockById('dinner')!.minutes, 45, reason: wake);
        expectNoOverlap(p);
      }
      // On a gym day the evening is 15 minutes over: free goes 120 → 105.
      final p = buildPlan(workday, DayInput(wake: at('07:00'), dayTypes: {'gym'}));
      expect(p.cuts, [const Cut(blockId: 'free', fromMinutes: 120, toMinutes: 105)]);
    });

    test('a later bedtime override widens only the last segment', () {
      final p = buildPlan(
        workday,
        DayInput(wake: at('07:00'), dayTypes: {'rest'}, bedtimeOverride: const ClockTime(23, 30)),
      );
      expect(p.blockById('free')!.minutes, 120 + 75 + 30);
      expect(p.blocks.last.end, at('23:30'));
    });
  });

  group('actions', () {
    late Plan day;
    setUp(() => day = buildPlan(sample, DayInput(wake: at('06:15'), dayTypes: {'gym'})));

    test('skip a future block: it leaves and free time grows into the space', () {
      final now = at('12:00');
      final after = applyAction(day, const SkipAction('side_project'), now);
      expect(after.blockById('side_project'), isNull);
      expect(after.input.removed, contains('side_project'));
      expect(after.blockById('free2')!.minutes, day.blockById('free2')!.minutes + 135);
      expect(after.blocks.last.end, at('22:30'));
    });

    test('skip the current block: it leaves and the rest starts now', () {
      final now = at('12:00');
      final after = applyAction(day, const SkipAction('deep_work'), now);
      expect(after.blockById('deep_work'), isNull);
      expect(after.blockById('free1')!.start, now);
      final preview = previewAction(day, const SkipAction('deep_work'), now);
      expect(
        preview.any((c) => c.kind == PlanChangeKind.dropped && c.block.id == 'deep_work'),
        isTrue,
      );
    });

    test('done on the current block ends it now', () {
      final now = at('12:00');
      final after = applyAction(day, const DoneAction('deep_work'), now);
      expect(after.blockById('deep_work')!.end, now);
      expect(after.blockById('free1')!.start, now);
      expect(after.blocks.last.end, at('22:30'));
    });

    test('done on a future block removes it from today', () {
      final after = applyAction(day, const DoneAction('review'), at('12:00'));
      expect(after.blockById('review'), isNull);
    });

    test('running late restarts the current block from now', () {
      final now = at('11:00');
      final after = applyAction(day, const RunningLateAction(), now);
      final deep = after.blockById('deep_work')!;
      expect(deep.start, now);
      // 15 min later than planned: the 15 spare minutes absorb it, so no cuts.
      expect(deep.minutes, 165);
      expect(after.cuts, isEmpty);
      expect(after.blocks.last.end, at('22:30'));
    });

    test('earlier cuts on locked blocks are kept after a re-plan', () {
      final late = buildPlan(sample, DayInput(wake: at('10:00'), dayTypes: {'gym'}));
      expect(late.cutFor('side_project'), isNotNull);
      final now = late.blockById('snack')!.start.add(const Duration(minutes: 5));
      final after = applyAction(late, const ExtendAction(10), now);
      expect(after.cutFor('side_project'), late.cutFor('side_project'));
    });

    test('extend with nothing in progress changes nothing', () {
      expect(identical(applyAction(day, const ExtendAction(15), at('05:00')), day), isTrue);
    });

    test('actions stack', () {
      final a = applyAction(day, const ExtendAction(15), at('12:00'));
      final b = applyAction(a, const SkipAction('gaming'), at('12:10'));
      final c = applyAction(b, const ExtendAction(15), at('12:20'));
      expect(c.blockById('gaming'), isNull);
      expect(c.blockById('deep_work')!.end, at('14:00'));
      expect(c.blocks.last.end, at('22:30'));
      expectNoOverlap(c);
    });
  });

  group('edge cases', () {
    test('overflow is reported and nothing without a min shrinks', () {
      final p = buildPlan(sample, DayInput(wake: at('17:00'), dayTypes: {'gym', 'cook'}));
      expect(p.overflowMinutes, greaterThan(0));
      for (final b in p.blocks.where((b) => !b.block.isShrinkable)) {
        expect(b.minutes, b.block.minutes, reason: b.id);
      }
    });

    test('a bedtime after midnight belongs to the same day', () {
      final s = Schedule(
        bedtime: const ClockTime(0, 30),
        wakeTarget: const ClockTime(8, 30),
        dayTypes: const ['normal'],
        blocks: const [
          BlockDef(id: 'a', name: 'A', minutes: 60),
          BlockDef(id: 'free', name: 'Free', minutes: 30, min: 0, priority: 9),
        ],
      );
      final p = buildPlan(s, DayInput(wake: at('22:00')));
      expect(p.blocks.last.end, DateTime(2026, 10, 27, 0, 30));
      expect(p.blockById('free')!.minutes, 145 - 60);
    });

    test('formatDuration matches the mockups', () {
      expect(formatDuration(25), '25 min');
      expect(formatDuration(60), '1h');
      expect(formatDuration(75), '1h 15');
      expect(formatDuration(165), '2h 45');
      expect(formatDuration(65), '1h 05');
    });
  });
}
