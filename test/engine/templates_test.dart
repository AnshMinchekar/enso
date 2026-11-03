import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:enso/engine/planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// The starter templates must parse, contain no personal details, and give a
/// calm day at their own wake target for every combination of day types.
void main() {
  const files = ['student.md', 'nine_to_five.md', 'gym_focused.md'];

  for (final name in files) {
    group(name, () {
      final text = File('assets/templates/$name').readAsStringSync();
      final result = parseSchedule(text);

      test('parses with no errors', () {
        expect(result.errors, isEmpty);
      });

      test('fits the day at its wake target for every day-type combination', () {
        final s = result.schedule!;
        final types = s.dayTypes;
        for (var mask = 0; mask < (1 << types.length); mask++) {
          final selected = {
            for (var i = 0; i < types.length; i++)
              if (mask & (1 << i) != 0) types[i],
          };
          final wake = DateTime(2026, 11, 2, s.wakeTarget.hour, s.wakeTarget.minute);
          final p = buildPlan(s, DayInput(wake: wake, dayTypes: selected));
          expect(p.overflowMinutes, 0, reason: '$selected');
          expect(p.cuts, isEmpty, reason: '$selected');
          expect(
            p.blocks.last.end.hour * 60 + p.blocks.last.end.minute,
            s.bedtime.dayMinutes % 1440,
            reason: '$selected ends at bedtime',
          );
        }
      });

      test('a late start still fits by cutting flexible blocks only', () {
        final s = result.schedule!;
        final wake = DateTime(2026, 11, 2, s.wakeTarget.hour + 2, s.wakeTarget.minute);
        final p = buildPlan(s, DayInput(wake: wake, dayTypes: {s.dayTypes.first}));
        for (final c in p.cuts) {
          final def = s.blockById(c.blockId)!;
          expect(
            def.min != null || def.latestStart != null || def.isPinned,
            isTrue,
            reason: c.blockId,
          );
        }
      });

      test('has no personal details', () {
        expect(text.toLowerCase(), isNot(contains('ansh')));
        expect(RegExp(r'@|\d{3,}[- ]\d{3,}|https?://').hasMatch(text), isFalse);
      });
    });
  }
}
