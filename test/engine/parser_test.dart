import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Returns the 1-based line number of the first line containing [needle].
int lineOf(String text, String needle) =>
    text.split('\n').indexWhere((l) => l.contains(needle)) + 1;

void main() {
  group('fixtures', () {
    test('sample.md parses with zero errors', () {
      final result = parseSchedule(fixture('sample.md'));
      expect(result.errors, isEmpty);
      final s = result.schedule!;
      expect(s.bedtime, const ClockTime(22, 30));
      expect(s.wakeTarget, const ClockTime(6, 15));
      expect(s.dayTypes, ['gym', 'cook', 'rest']);
      expect(s.blocks, hasLength(17));
      expect(s.blocks.first.id, 'breakfast');
      expect(s.blocks.last.id, 'winddown');

      final preworkout = s.blockById('preworkout')!;
      expect(preworkout.onlyOn, {'gym'});
      expect(preworkout.latestStart, const ClockTime(14, 0));
      expect(preworkout.category, Category.body);

      final lunch = s.blockById('lunch')!;
      expect(lunch.rightAfter, 'cook');

      final deepWork = s.blockById('deep_work')!;
      expect(deepWork.minutes, 165);
      expect(deepWork.min, 105);
      expect(deepWork.priority, 2);
      expect(deepWork.isShrinkable, isTrue);

      final free1 = s.blockById('free1')!;
      expect(free1.min, 0);
      expect(free1.notify, isFalse);

      expect(s.blockById('breakfast')!.isShrinkable, isFalse);
      expect(s.blockById('breakfast')!.notify, isTrue);
      expect(s.blockById('breakfast')!.line, 9);
    });

    test('workday.md parses with zero errors', () {
      final result = parseSchedule(fixture('workday.md'));
      expect(result.errors, isEmpty);
      final s = result.schedule!;
      expect(s.bedtime, const ClockTime(23, 0));
      expect(s.blockById('commute_in')!.at, const ClockTime(8, 30));
      expect(s.blockById('work')!.at, const ClockTime(9, 0));
      expect(s.blockById('work')!.isPinned, isTrue);
      expect(s.blockById('gym')!.onlyOn, {'gym'});
    });
  });

  group('required spec cases', () {
    test('misspelt right_after target: one error, correct line, suggestion', () {
      final text = fixture('sample.md').replaceFirst('right_after: cook', 'right_after: cok');
      final result = parseSchedule(text);
      expect(result.schedule, isNull);
      expect(result.errors, hasLength(1));
      final e = result.errors.single;
      expect(e.line, lineOf(text, 'right_after: cok'));
      expect(e.line, 15);
      expect(e.message, "Lunch says right_after: cok, but there's no block with id cok.");
      expect(e.suggestion, 'cook');
    });

    test('missing minutes: one error with the correct line', () {
      final text = fixture('sample.md')
          .replaceFirst('{id: cook, name: Cook, minutes: 120,', '{id: cook, name: Cook,');
      final result = parseSchedule(text);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.line, lineOf(text, 'id: cook,'));
      expect(result.errors.single.message, contains('Cook has no minutes'));
    });

    test('overlapping pinned blocks in workday.md: one error', () {
      final text = fixture('workday.md').replaceFirst(
        '{id: commute_in, name: Commute, minutes: 30,',
        '{id: commute_in, name: Commute, minutes: 45,',
      );
      final result = parseSchedule(text);
      expect(result.errors, hasLength(1));
      final e = result.errors.single;
      expect(e.line, lineOf(text, 'id: work,'));
      expect(e.message, contains("can't overlap"));
    });
  });

  group('routine block', () {
    test('text without a routine block is reported as such', () {
      final result = parseSchedule('Here is your day!\n\n- Breakfast 08:00\n');
      expect(result.hasNoRoutineBlock, isTrue);
      expect(result.errors, hasLength(1));
      expect(result.schedule, isNull);
    });

    test('a non-routine code block does not count', () {
      final result = parseSchedule('```yaml\nbedtime: "22:30"\n```\n');
      expect(result.hasNoRoutineBlock, isTrue);
    });

    test('two routine blocks is an error on the second', () {
      final one = fixture('sample.md');
      final text = '$one\n$one';
      final result = parseSchedule(text);
      expect(result.hasNoRoutineBlock, isFalse);
      expect(result.errors, hasLength(1));
      expect(
        result.errors.single.line,
        30,
      ); // 26 lines + blank line, then the fence is line 3 of the copy
      expect(result.errors.single.message, contains('second routine block'));
    });

    test('an unclosed routine block is an error', () {
      final text = fixture('sample.md').replaceFirst(RegExp(r'```\s*$'), '');
      final result = parseSchedule(text);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.line, 3);
      expect(result.errors.single.message, contains('never closed'));
    });

    test('routine block wrapped in an outer markdown fence is found', () {
      final text = '````markdown\n${fixture('sample.md')}````\n';
      final result = parseSchedule(text);
      expect(result.errors, isEmpty);
      expect(result.schedule!.blocks, hasLength(17));
    });

    test('Windows line endings parse the same', () {
      final text = fixture('sample.md').replaceAll('\n', '\r\n');
      final result = parseSchedule(text);
      expect(result.errors, isEmpty);
      expect(result.schedule!.blockById('lunch')!.line, 15);
    });

    test('block-style YAML (not one line per block) also works', () {
      const text = '''
# Mine

```routine
bedtime: "22:00"
day_types: [normal]
blocks:
  - id: breakfast
    name: Breakfast
    minutes: 20
  - id: free
    name: Free time
    minutes: 60
    min: 0
    priority: 9
```
''';
      final result = parseSchedule(text);
      expect(result.errors, isEmpty);
      final s = result.schedule!;
      expect(s.wakeTarget, const ClockTime(14, 0), reason: 'defaults to bedtime minus 8 hours');
      expect(s.blockById('free')!.line, 10);
    });

    test('invalid YAML reports the file line', () {
      final text = fixture('sample.md').replaceFirst(
        '{id: snack, name: Snack, minutes: 20, category: food}',
        '{id: snack, name: Snack, minutes: 20, category: food',
      );
      final result = parseSchedule(text);
      expect(result.schedule, isNull);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains("isn't valid YAML"));
      expect(result.errors.single.line, greaterThanOrEqualTo(lineOf(text, 'id: snack')));
    });
  });

  group('validation collects every error', () {
    const header = '```routine\nbedtime: "22:30"\nday_types: [gym, rest]\nblocks:\n';

    ParseResult parseBlocks(String blocks, {String head = header}) =>
        parseSchedule('$head$blocks```\n');

    test('bad times are reported with the field line', () {
      final result = parseSchedule(
        '```routine\nbedtime: "25:00"\nwake_target: 0630\nday_types: [gym]\nblocks:\n'
        '  - {id: a, name: A, minutes: 10, latest_start: "9am"}\n```\n',
      );
      expect(result.errors.map((e) => e.line), [2, 3, 6]);
      expect(result.errors.first.message, contains('bedtime'));
    });

    test('missing top-level fields', () {
      final result = parseSchedule('```routine\nwake_target: "06:00"\n```\n');
      expect(result.errors, hasLength(3));
      expect(
        result.errors.map((e) => e.message).join(' '),
        allOf(contains('no bedtime'), contains('no day_types'), contains('no blocks')),
      );
    });

    test('missing id, name and minutes are all reported', () {
      final result = parseBlocks('  - {detail: nothing}\n');
      expect(result.errors, hasLength(3));
      expect(result.errors.every((e) => e.line == 5), isTrue);
    });

    test('duplicate ids', () {
      final result = parseBlocks(
        '  - {id: walk, name: Walk, minutes: 30}\n'
        '  - {id: walk, name: Evening walk, minutes: 30}\n',
      );
      expect(result.errors, hasLength(1));
      expect(result.errors.single.line, 6);
      expect(result.errors.single.message, contains('already uses'));
    });

    test('min larger than minutes, and min without priority', () {
      final result = parseBlocks(
        '  - {id: a, name: A, minutes: 30, min: 40, priority: 3}\n'
        '  - {id: b, name: B, minutes: 30, min: 10}\n',
      );
      expect(result.errors, hasLength(2));
      expect(result.errors[0].message, contains('min must not be larger'));
      expect(result.errors[1].message, contains('no priority'));
    });

    test('priority out of range', () {
      final result = parseBlocks('  - {id: a, name: A, minutes: 30, min: 10, priority: 12}\n');
      expect(result.errors.single.message, contains('1 (cut last) to 9 (cut first)'));
    });

    test('only_on and skip_on must use day_types, with a suggestion', () {
      final result = parseBlocks(
        '  - {id: a, name: Gym, minutes: 30, only_on: [gim]}\n'
        '  - {id: b, name: Nap, minutes: 30, skip_on: [office]}\n',
      );
      expect(result.errors, hasLength(2));
      expect(result.errors[0].suggestion, 'gym');
      expect(result.errors[1].suggestion, isNull, reason: 'office is not close to anything');
    });

    test('category must be allowed; errand is reserved', () {
      final result = parseBlocks(
        '  - {id: a, name: A, minutes: 30, category: fod}\n'
        '  - {id: b, name: B, minutes: 30, category: errand}\n',
      );
      expect(result.errors, hasLength(2));
      expect(result.errors[0].suggestion, 'food');
      expect(result.errors[1].message, contains('kept for errands'));
    });

    test('unknown fields are reported with a suggestion', () {
      final result = parseBlocks('  - {id: a, name: A, minutes: 30, minimum: 10, priority: 2}\n');
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('minimum'));
    });

    test('right_after can be suggested from a block name', () {
      final result = parseBlocks(
        '  - {id: cooking, name: Cook, minutes: 60}\n'
        '  - {id: lunch, name: Lunch, minutes: 30, right_after: Cook}\n',
      );
      expect(result.errors.single.suggestion, 'cooking');
    });

    test('right_after pointing at a block that has its own error is not double-reported', () {
      final result = parseBlocks(
        '  - {id: cook, name: Cook}\n'
        '  - {id: lunch, name: Lunch, minutes: 30, right_after: cook}\n',
      );
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('no minutes'));
    });

    test('pinned blocks out of clock order', () {
      final result = parseBlocks(
        '  - {id: a, name: Lecture, minutes: 60, at: "11:00"}\n'
        '  - {id: b, name: Seminar, minutes: 60, at: "09:00"}\n',
      );
      expect(result.errors.single.message, contains('clock order'));
      expect(result.errors.single.line, 6);
    });

    test('pinned block ending after bedtime', () {
      final result = parseBlocks('  - {id: a, name: Late shift, minutes: 120, at: "21:30"}\n');
      expect(result.errors.single.message, contains('after bedtime'));
    });

    test('bedtime after midnight counts as the end of the same day', () {
      final result = parseBlocks(
        '  - {id: a, name: Late shift, minutes: 120, at: "21:30"}\n',
        head: '```routine\nbedtime: "00:30"\nday_types: [gym]\nblocks:\n',
      );
      expect(result.errors, isEmpty);
      expect(result.schedule!.wakeTarget, const ClockTime(16, 30));
    });

    test('errors come back sorted by line', () {
      final result = parseSchedule(
        '```routine\nbedtime: "nope"\nday_types: [gym]\nblocks:\n'
        '  - {id: a, name: A, minutes: 30, right_after: zzz}\n'
        '  - {id: b, name: B}\n```\n',
      );
      final lines = result.errors.map((e) => e.line).toList();
      expect(lines, [...lines]..sort());
      expect(lines, hasLength(3));
    });
  });

  group('helpers', () {
    test('ClockTime parsing and ordering', () {
      expect(ClockTime.tryParse('06:05'), const ClockTime(6, 5));
      expect(ClockTime.tryParse('6:05'), const ClockTime(6, 5));
      expect(ClockTime.tryParse('24:00'), isNull);
      expect(ClockTime.tryParse('12:60'), isNull);
      expect(ClockTime.tryParse('noon'), isNull);
      expect(const ClockTime(0, 30).compareTo(const ClockTime(23, 0)), greaterThan(0));
      expect(const ClockTime(6, 0).addMinutes(-8 * 60), const ClockTime(22, 0));
      expect(const ClockTime(7, 5).toString(), '07:05');
    });

    test('closestMatch only suggests close matches', () {
      expect(closestMatch('cok', ['cook', 'lunch']), 'cook');
      expect(closestMatch('lnuch', ['cook', 'lunch']), 'lunch');
      expect(closestMatch('deepwork', ['deep_work', 'gym']), 'deep_work');
      expect(closestMatch('banana', ['cook', 'lunch']), isNull);
      expect(closestMatch('x', ['y']), isNull);
    });
  });
}
