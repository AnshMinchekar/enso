import 'dart:convert';
import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:enso/engine/planner.dart';
import 'package:enso/engine/serialization.dart';
import 'package:flutter_test/flutter_test.dart';

final Schedule sample = parseSchedule(File('test/fixtures/sample.md').readAsStringSync()).schedule!;
DateTime at(int h, int m) => DateTime(2026, 10, 26, h, m);

/// Round-trips through a JSON string, as storage does.
Plan? roundTrip(Plan p) =>
    planFromJson((jsonDecode(jsonEncode(planToJson(p))) as Map).cast<String, Object?>(), sample);

void expectSamePlan(Plan a, Plan b) {
  expect(b.blocks.map((x) => (x.id, x.start, x.end)), a.blocks.map((x) => (x.id, x.start, x.end)));
  expect(b.cuts, a.cuts);
  expect(b.overflowMinutes, a.overflowMinutes);
  expect(b.bedtime, a.bedtime);
}

void main() {
  test('a freshly built day round-trips', () {
    final p = buildPlan(
      sample,
      DayInput(
        wake: at(7, 55),
        dayTypes: {'gym', 'cook'},
        errands: const [Errand('Haircut', 60)],
        bedtimeOverride: const ClockTime(23, 0),
      ),
    );
    final back = roundTrip(p)!;
    expectSamePlan(p, back);
    expect(back.input.dayTypes, {'gym', 'cook'});
    expect(back.input.errands.single.name, 'Haircut');
    expect(back.input.bedtimeOverride, const ClockTime(23, 0));
  });

  test('a day after actions round-trips, including cuts on finished blocks', () {
    var p = buildPlan(sample, DayInput(wake: at(10, 0), dayTypes: {'gym'}));
    p = applyAction(p, const ExtendAction(15), at(12, 0));
    p = applyAction(p, const SkipAction('gaming'), at(12, 5));
    p = applyAction(p, DoneAction(p.blockAt(at(12, 10))!.id), at(12, 10));
    final back = roundTrip(p)!;
    expectSamePlan(p, back);
    expect(back.input.removed, contains('gaming'));
    expect(back.input.locked, isNotEmpty);
    expect(back.input.now, at(12, 10));
  });

  test('unreadable or older data gives null, never a guess', () {
    expect(planFromJson({'format': 99}, sample), isNull);
    expect(planFromJson({'format': kDayFormat, 'input': 'nope'}, sample), isNull);
    expect(planFromJson(const {}, sample), isNull);
  });
}
