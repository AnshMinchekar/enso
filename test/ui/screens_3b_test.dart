import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:enso/ui/app.dart';
import 'package:enso/ui/app_state.dart';
import 'package:enso/ui/schedule_summary.dart';
import 'package:enso/ui/screens/make_with_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final String sampleText = File('test/fixtures/sample.md').readAsStringSync();
final String workdayText = File('test/fixtures/workday.md').readAsStringSync();
final Schedule sample = parseSchedule(sampleText).schedule!;
final Schedule workday = parseSchedule(workdayText).schedule!;

DateTime at(int h, int m) => DateTime(2026, 10, 26, h, m);

/// A fake system clipboard.
class FakeClipboard {
  String? text;

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      switch (call.method) {
        case 'Clipboard.setData':
          text = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return text == null ? null : {'text': text};
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }
}

Future<AppState> pumpApp(WidgetTester tester, {DateTime? now}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final time = now ?? at(10, 0);
  final state = AppState(clock: () => time, initialSchedule: sample);
  await tester.pumpWidget(EnsoApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Settings'));
  await tester.pumpAndSettle();
}

Future<void> openScheduleFile(WidgetTester tester) async {
  await openSettings(tester);
  await tester.tap(find.text('Schedule file'));
  await tester.pumpAndSettle();
}

void main() {
  group('schedule summary', () {
    test('block labels', () {
      expect(blockLengthLabel(sample.blockById('breakfast')!), '20 min · fixed');
      expect(blockLengthLabel(sample.blockById('gym')!), '2h · gym days');
      expect(blockLengthLabel(sample.blockById('deep_work')!), '2h 45 · min 1h 45');
      expect(blockLengthLabel(sample.blockById('free1')!), '45 min · can drop');
      expect(blockLengthLabel(workday.blockById('work')!), '8h · at 09:00');
    });

    test('rules for sample.md', () {
      expect(scheduleRules(sample), [
        'Lights out is 22:30 and never moves.',
        'Breakfast, Pre-workout, Gym and 7 more are never shortened.',
        'When the day is full, free time goes first, then Gaming, then Side project, then Review.',
        'Pre-workout and Gym only appear on gym days.',
        'Cook only appears on cook days.',
        'Lunch comes right after Cook.',
        'Pre-workout is dropped if it would start after 14:00.',
      ]);
      expect(scheduleCounts(sample), '17 blocks · 7 rules');
    });

    test('rules for workday.md mention pinned blocks', () {
      final rules = scheduleRules(workday);
      expect(rules, contains('Commute is fixed at 08:30.'));
      expect(rules, contains('Work is fixed at 09:00.'));
      expect(
        rules,
        contains('When the day is full, free time goes first, then Reading, then Gym.'),
      );
    });

    test('pasted file names come from the heading', () {
      expect(pastedFileName(sampleText), 'sample-routine.md');
      expect(pastedFileName("# Ansh's routine\n"), 'anshs-routine.md');
      expect(pastedFileName('```routine\n```'), 'my-schedule.md');
    });

    test('block lines are counted in text that did not parse', () {
      expect(countBlockLines(sampleText), 17);
    });
  });

  testWidgets('settings: bedtime override re-plans and can be cleared', (tester) async {
    final state = await pumpApp(tester, now: at(6, 20));
    state.buildDay(wake: at(6, 15), dayTypes: {'gym'}, errands: const []);
    await tester.pumpAndSettle();
    await openSettings(tester);

    expect(find.text('Bedtime'), findsOneWidget);
    expect(find.text('22:30'), findsOneWidget);
    expect(find.text('Heads-up before a block ends'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('Soft chime'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Everything runs on this phone. No account, no server.'), findsOneWidget);

    state.setBedtime(const ClockTime(23, 0));
    await tester.pumpAndSettle();
    expect(find.text('23:00'), findsOneWidget);
    expect(state.plan!.bedtime, at(23, 0));
    expect(state.plan!.blocks.last.end, at(23, 0));

    await tester.tap(find.text('Bedtime'));
    await tester.pumpAndSettle();
    expect(find.text('From your file: 22:30. A time set here wins on this phone.'), findsOneWidget);
    await tester.tap(find.text('Use the file’s bedtime'));
    await tester.pumpAndSettle();
    expect(state.bedtimeOverride, isNull);
    expect(state.plan!.bedtime, at(22, 30));
  });

  testWidgets('settings: heads-up choice', (tester) async {
    final state = await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.text('Heads-up before a block ends'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 min before'));
    await tester.pumpAndSettle();
    expect(state.headsUpMinutes, 10);
    expect(find.text('10 min'), findsOneWidget);
  });

  testWidgets('schedule file screen summarises the running schedule', (tester) async {
    await pumpApp(tester);
    await openScheduleFile(tester);
    expect(find.text('sample.md'), findsOneWidget);
    expect(find.text('Running since 26 Oct · 17 blocks · 7 rules'), findsOneWidget);
    expect(find.text('Blocks'), findsOneWidget);
    expect(find.text('20 min · fixed'), findsNWidgets(2)); // Breakfast and Snack
    expect(find.text('Paste from clipboard'), findsOneWidget);
    expect(find.text('Make one with AI'), findsOneWidget);
    expect(find.text('Import file'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lunch comes right after Cook.'), 200);
    expect(find.text('Lunch comes right after Cook.'), findsOneWidget);
  });

  group('paste', () {
    testWidgets('valid schedule: use it and today rebuilds', (tester) async {
      final clipboard = FakeClipboard()..install(tester);
      final state = await pumpApp(tester, now: at(7, 10));
      state.buildDay(wake: at(7, 0), dayTypes: {'gym'}, errands: const []);
      await tester.pumpAndSettle();
      await openScheduleFile(tester);

      clipboard.text = workdayText;
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pumpAndSettle();
      expect(find.text('Pasted schedule'), findsOneWidget);
      expect(find.text('From your clipboard'), findsOneWidget);
      expect(find.text('9 blocks · 6 rules · ready to use'), findsOneWidget);

      await tester.tap(find.text('Use this schedule'));
      await tester.pumpAndSettle();
      expect(state.scheduleName, 'workday-routine.md');
      expect(state.schedule!.bedtime, const ClockTime(23, 0));
      expect(state.plan!.blockById('work'), isNotNull);
      expect(state.plan!.input.dayTypes, {'gym'});
      expect(find.text('Your day'), findsOneWidget, reason: 'back on Today');
    });

    testWidgets('no schedule found, then try again', (tester) async {
      final clipboard = FakeClipboard()..install(tester);
      final state = await pumpApp(tester);
      await openScheduleFile(tester);
      clipboard.text = 'Sure! Breakfast at 8, gym at 9.';
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pumpAndSettle();
      expect(find.text('No schedule found'), findsOneWidget);
      expect(
        find.text(
          'The copied text has no Enso schedule in it. Copy the assistant’s whole answer, then try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('See the steps'), findsOneWidget);

      clipboard.text = workdayText;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Use this schedule'), findsOneWidget);
      expect(state.scheduleName, 'sample.md', reason: 'nothing changes until used');
    });

    testWidgets('errors show line cards with suggestions', (tester) async {
      final clipboard = FakeClipboard()..install(tester);
      final state = await pumpApp(tester);
      await openScheduleFile(tester);
      clipboard.text = sampleText.replaceFirst('right_after: cook', 'right_after: cok');
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pumpAndSettle();
      expect(find.text('17 blocks · 1 line needs a fix'), findsOneWidget);
      expect(find.text('LINE 15'), findsOneWidget);
      expect(
        find.text("Lunch says right_after: cok, but there's no block with id cok."),
        findsOneWidget,
      );
      expect(find.text('Did you mean cook?'), findsOneWidget);
      expect(find.text('Paste again'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule file'), findsOneWidget);
      expect(state.scheduleName, 'sample.md');
    });
  });

  testWidgets('make one with AI: copy prompt shows Copied, then resets', (tester) async {
    final clipboard = FakeClipboard()..install(tester);
    await pumpApp(tester);
    await openScheduleFile(tester);
    await tester.tap(find.text('Make one with AI'));
    await tester.pumpAndSettle();
    expect(
      find.text('Use any assistant you like. Enso never sends anything itself.'),
      findsOneWidget,
    );
    expect(find.text('Copy the prompt'), findsOneWidget);
    expect(find.text('Paste it into any AI assistant'), findsOneWidget);
    expect(find.text('Copy the answer back'), findsOneWidget);

    await tester.tap(find.text('Copy prompt'));
    await tester.pumpAndSettle();
    expect(clipboard.text, File('assets/prompts/create_with_ai.md').readAsStringSync());
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Copy prompt'), findsOneWidget);

    clipboard.text = workdayText;
    await tester.tap(find.text('Paste schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Use this schedule'), findsOneWidget);
  });

  testWidgets('onboarding (debug entry): three steps', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.text('Show onboarding'));
    await tester.pumpAndSettle();
    expect(find.text('Your whole day, built from the moment you wake.'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Start from a template'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('9 to 5'), findsOneWidget);
    expect(find.text('Gym-focused'), findsOneWidget);
    expect(find.text('Import a schedule file'), findsOneWidget);
    expect(
      find.text('Describe your day to any AI assistant, paste the result back'),
      findsOneWidget,
    );
    await tester.tap(find.text('Gym-focused'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Two small permissions'), findsOneWidget);
    expect(
      find.text('So a 12:30 reminder arrives at 12:30, not a few minutes later.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });
}
