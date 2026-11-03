import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:enso/ui/app.dart';
import 'package:enso/ui/app_state.dart';
import 'package:enso/ui/screens/today_screen.dart';
import 'package:enso/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Schedule sample = parseSchedule(File('test/fixtures/sample.md').readAsStringSync()).schedule!;

/// A clock the test can move.
class TestClock {
  TestClock(this.now);
  DateTime now;
  DateTime call() => now;
}

DateTime at(int h, int m) => DateTime(2026, 10, 26, h, m);

Future<AppState> pumpApp(
  WidgetTester tester,
  TestClock clock, {
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final state = AppState(clock: clock.call, initialSchedule: sample);
  await tester.pumpWidget(EnsoApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

/// Builds a day directly, as "Build my day" would.
Future<void> buildDay(
  WidgetTester tester,
  AppState state, {
  required DateTime wake,
  Set<String> types = const {'gym'},
}) async {
  state.buildDay(wake: wake, dayTypes: types, errands: const []);
  await tester.pumpAndSettle();
}

void main() {
  group('ambience', () {
    test('periods follow the clock', () {
      expect(Ambience.at(at(4, 0)), Ambience.morning);
      expect(Ambience.at(at(11, 59)), Ambience.morning);
      expect(Ambience.at(at(12, 0)), Ambience.afternoon);
      expect(Ambience.at(at(17, 59)), Ambience.afternoon);
      expect(Ambience.at(at(18, 0)), Ambience.evening);
      expect(Ambience.at(at(3, 59)), Ambience.evening);
      expect(Ambience.evening.brightness, Brightness.dark);
      expect(Ambience.afternoon.brightness, Brightness.light);
    });
  });

  group('before check-in', () {
    for (final (time, greeting) in [
      (at(6, 7), 'Good morning.'),
      (at(13, 40), 'Good afternoon.'),
      (at(19, 30), 'Good evening.'),
    ]) {
      testWidgets('greets with "$greeting"', (tester) async {
        await pumpApp(tester, TestClock(time));
        expect(find.text(greeting), findsOneWidget);
        expect(find.text('When did you wake up?'), findsOneWidget);
        expect(find.text('Check in'), findsOneWidget);
      });
    }
  });

  testWidgets('check-in builds the day and lands on Today', (tester) async {
    final clock = TestClock(at(6, 7));
    final state = await pumpApp(tester, clock);

    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    expect(find.text('You woke up at'), findsOneWidget);
    expect(find.text('Set to now, scroll to adjust'), findsOneWidget);
    // Wake prefilled with now, rounded down to 5 minutes: 06:05.
    expect(find.text('06'), findsWidgets);
    expect(find.text('05'), findsWidgets);
    // 06:05 → 22:30 is 16h 25.
    expect(find.text('16h 25 until lights out'), findsOneWidget);

    await tester.tap(find.text('Gym'));
    await tester.pump();
    await tester.tap(find.text('Build my day'));
    await tester.pumpAndSettle();

    expect(state.checkedIn, isTrue);
    expect(state.plan!.input.wake, at(6, 5));
    expect(state.plan!.input.dayTypes, {'gym'});
    expect(find.text('You woke up at'), findsNothing);
    expect(find.text('Your day'), findsOneWidget);
    // Day starts at 06:10 with breakfast; at 06:07 it's the next block.
    expect(find.text('Breakfast'), findsWidgets);
  });

  testWidgets('add an errand at check-in', (tester) async {
    final state = await pumpApp(tester, TestClock(at(6, 7)));
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add errand'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Haircut');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget);

    await tester.tap(find.text('Build my day'));
    await tester.pumpAndSettle();
    expect(state.plan!.blockById('errand_1')!.block.name, 'Haircut');
  });

  group('today', () {
    testWidgets('normal day shows now, up next and the timeline', (tester) async {
      final clock = TestClock(at(6, 15));
      final state = await pumpApp(tester, clock);
      await buildDay(tester, state, wake: at(6, 15));
      clock.now = at(11, 0);
      state.tick();
      await tester.pumpAndSettle();

      expect(state.current!.id, 'deep_work');
      expect(find.text('NOW'), findsOneWidget);
      expect(find.text('Deep work'), findsWidgets);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('Free'), findsWidgets);
      expect(find.text('Running late?'), findsOneWidget);
      // No cuts on this day, so no summary.
      expect(find.textContaining('a little shorter'), findsNothing);
    });

    testWidgets('late start shows the quiet summary card', (tester) async {
      final clock = TestClock(at(8, 0));
      final state = await pumpApp(tester, clock);
      await buildDay(tester, state, wake: at(7, 55), types: {'gym', 'cook'});

      expect(
        find.text(
          'You started at 07:55, so two blocks are a little shorter and two are left out today.',
        ),
        findsOneWidget,
      );
      expect(find.text('2h 15 → 1h 30'), findsOneWidget);
      expect(find.text('1h 30 → 1h'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You started at'), findsNothing);
    });

    testWidgets('block sheet: +15 re-plans live, Skip closes and removes', (tester) async {
      final clock = TestClock(at(6, 15));
      final state = await pumpApp(tester, clock);
      await buildDay(tester, state, wake: at(6, 15));
      clock.now = at(12, 0);
      state.tick();
      await tester.pumpAndSettle();

      // Open from the hero card.
      await tester.tap(find.text('Deep work').first);
      await tester.pumpAndSettle();
      expect(find.text('NOW · FOCUS'), findsOneWidget);
      expect(find.text('Can shrink to'), findsOneWidget);
      expect(find.text('1h 45'), findsOneWidget);
      expect(find.text('Comes after'), findsOneWidget);
      expect(
        find.text('With +15 min, Free moves to 13:45 and Free becomes 1h 25.'),
        findsOneWidget,
      );

      await tester.tap(find.text('+15 min'));
      await tester.pumpAndSettle();
      expect(state.plan!.blockById('deep_work')!.end, at(13, 45));
      expect(find.text('NOW · FOCUS'), findsOneWidget, reason: 'sheet stays open');

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('NOW · FOCUS'), findsNothing);
      expect(state.plan!.blockById('deep_work'), isNull);
    });

    testWidgets('running late: the sheet previews, then restarts the block from now', (
      tester,
    ) async {
      final clock = TestClock(at(6, 15));
      final state = await pumpApp(tester, clock);
      await buildDay(tester, state, wake: at(6, 15));
      clock.now = at(11, 0);
      state.tick();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Running late?'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Deep work was planned from 10:45. Start it again now, at 11:00, '
          'and the rest of the day re-plans around it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Starting from now'), findsOneWidget);
      await tester.tap(find.text('Start Deep work now'));
      await tester.pumpAndSettle();
      expect(state.plan!.blockById('deep_work')!.start, at(11, 0));
    });

    testWidgets('running late before anything starts: nothing needs to move', (tester) async {
      final clock = TestClock(at(6, 16));
      final state = await pumpApp(tester, clock);
      await buildDay(tester, state, wake: at(6, 15));
      final before = state.plan;
      await tester.tap(find.text('Running late?'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nothing has started yet. Breakfast begins at 06:20, so nothing needs to move.'),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(identical(state.plan, before), isTrue);
    });

    testWidgets('earlier blocks fold away and the whole day scrolls', (tester) async {
      final clock = TestClock(at(6, 15));
      final state = await pumpApp(tester, clock);
      await buildDay(tester, state, wake: at(6, 15));
      clock.now = at(11, 0);
      state.tick();
      await tester.pumpAndSettle();
      // Breakfast…Lunch are earlier; Lunch (the block before now) stays.
      expect(find.text('Earlier today · 5 blocks'), findsOneWidget);
      expect(find.text('Language practice'), findsNothing);
      await tester.tap(find.text('Earlier today · 5 blocks'));
      await tester.pumpAndSettle();
      expect(find.text('Language practice'), findsOneWidget);
      expect(find.text('Hide earlier blocks'), findsOneWidget);

      // Everything scrolls together: drag up and the hero card leaves.
      await tester.drag(find.text('Your day'), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('NOW'), findsNothing);
      await tester.drag(find.text('Gaming'), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(find.text('Lights out'), findsWidgets, reason: 'the end of the day is reachable');
    });

    testWidgets('wind down after the last block starts', (tester) async {
      final clock = TestClock(at(6, 15));
      final state = await pumpApp(tester, clock);
      await buildDay(tester, state, wake: at(6, 15));
      clock.now = at(22, 10);
      state.tick();
      await tester.pumpAndSettle();

      expect(state.isWindDown, isTrue);
      expect(find.text('Lights out at'), findsOneWidget);
      expect(find.text('22:30'), findsOneWidget);
      expect(find.text('Twenty quiet minutes left. The day is done.'), findsOneWidget);
      expect(find.text('Wake around 06:15'), findsOneWidget);
      expect(find.text('7h 45 of sleep'), findsOneWidget);
    });
  });

  group('copy helpers', () {
    test('wind down line', () {
      expect(windDownLine(20), 'Twenty quiet minutes left. The day is done.');
      expect(windDownLine(1), 'One quiet minute left. The day is done.');
      expect(windDownLine(75), '1h 15 of quiet left. The day is done.');
      expect(windDownLine(0), 'Past lights out. Sleep well.');
    });
  });

  group('small phone', () {
    testWidgets('360 × 740: check-in and Today lay out without overflow', (tester) async {
      final clock = TestClock(at(8, 0));
      final state = await pumpApp(tester, clock, size: const Size(360, 740));
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build my day'));
      await tester.pumpAndSettle();
      expect(state.checkedIn, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
