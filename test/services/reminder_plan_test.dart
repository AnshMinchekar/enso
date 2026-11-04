import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:enso/engine/planner.dart';
import 'package:enso/services/notifications.dart';
import 'package:enso/services/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

final Schedule sample = parseSchedule(File('test/fixtures/sample.md').readAsStringSync()).schedule!;
DateTime at(int h, int m) => DateTime(2026, 10, 26, h, m);

void main() {
  final plan = buildPlan(sample, DayInput(wake: at(6, 15), dayTypes: {'gym'}));

  test('a block-change notification at each block start, in the mockup wording', () {
    final r = remindersFor(plan, at(6, 0), headsUpMinutes: 5);
    final starts = r.where((x) => x.kind == ReminderKind.blockStart).toList();
    // free1 and free2 have notify: false.
    expect(starts.map((x) => x.blockId), isNot(contains('free1')));
    expect(starts.map((x) => x.blockId), isNot(contains('free2')));
    expect(starts, hasLength(plan.blocks.length - 2));

    final deep = starts.firstWhere((x) => x.blockId == 'deep_work');
    expect(deep.at, at(10, 45));
    expect(deep.title, 'Enso · now');
    expect(deep.body, 'Deep work, until 13:30. Next, Free.');
    expect(deep.hasActions, isTrue);

    final last = starts.last;
    expect(last.blockId, 'winddown');
    expect(last.body, 'Wind down, until 22:30. Next, Lights out.');
  });

  test('heads-ups come before each block ends, with the chosen length', () {
    final r = remindersFor(plan, at(6, 0), headsUpMinutes: 5);
    final gym = r.firstWhere((x) => x.kind == ReminderKind.headsUp && x.blockId == 'gym');
    expect(gym.at, at(9, 25));
    expect(gym.title, 'Enso · 09:25');
    expect(gym.body, '5 minutes left in Gym. Shower + snack next.');
    expect(gym.hasActions, isFalse);

    final ten = remindersFor(plan, at(6, 0), headsUpMinutes: 10);
    expect(
      ten.firstWhere((x) => x.kind == ReminderKind.headsUp && x.blockId == 'gym').at,
      at(9, 20),
    );
  });

  test('heads-ups skip blocks shorter than the heads-up', () {
    final r = remindersFor(plan, at(6, 0), headsUpMinutes: 15);
    // Pre-workout lasts exactly 15 minutes and late snack 15 minutes.
    final ids = r.where((x) => x.kind == ReminderKind.headsUp).map((x) => x.blockId);
    expect(ids, isNot(contains('preworkout')));
    expect(ids, isNot(contains('late_snack')));
    expect(ids, contains('gym'));
  });

  test('nothing in the past is scheduled', () {
    final r = remindersFor(plan, at(12, 0), headsUpMinutes: 5);
    expect(r.every((x) => x.at.isAfter(at(12, 0))), isTrue);
    expect(r.first.kind, ReminderKind.headsUp);
    expect(r.first.blockId, 'deep_work');
  });

  test('ids are stable and unique, sorted by time', () {
    final r = remindersFor(plan, at(6, 0), headsUpMinutes: 5);
    expect(r.map((x) => x.id).toSet(), hasLength(r.length));
    for (var i = 1; i < r.length; i++) {
      expect(r[i].at.isBefore(r[i - 1].at), isFalse);
    }
  });

  test('each sound has its own channel', () {
    expect(channelIdFor('Soft chime'), 'enso_soft_chime');
    expect(channelIdFor('Silent'), 'enso_silent');
    expect(kChannelName, 'Enso');
  });
}
