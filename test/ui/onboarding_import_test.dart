import 'dart:io';

import 'package:enso/engine/parser.dart';
import 'package:enso/services/storage.dart';
import 'package:enso/ui/app.dart';
import 'package:enso/ui/app_state.dart';
import 'package:enso/ui/screens/make_with_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final String sampleText = File('test/fixtures/sample.md').readAsStringSync();
final String workdayText = File('test/fixtures/workday.md').readAsStringSync();
DateTime at(int h, int m) => DateTime(2026, 10, 26, h, m);

void main() {
  late MemoryStore store;
  late AppState state;
  String? clipboard;

  Future<void> launch(WidgetTester tester, {bool firstLaunch = true}) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.getData') return clipboard == null ? null : {'text': clipboard};
      return null;
    });
    if (!firstLaunch) {
      store.schedule = StoredSchedule(name: 'sample.md', text: sampleText, since: at(6, 0));
    }
    state = AppState(clock: () => at(7, 0), store: store);
    await state.start();
    await tester.pumpWidget(EnsoApp(state: state));
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = MemoryStore();
    clipboard = null;
  });

  testWidgets('first launch: onboarding, a template, permissions, then Today', (tester) async {
    await launch(tester);
    expect(state.onboarding, isTrue);
    expect(find.text('Your whole day, built from the moment you wake.'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    // Nothing chosen yet: Continue waits.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Start from a template'), findsOneWidget);

    await tester.tap(find.text('Gym-focused'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Two small permissions'), findsOneWidget);
    expect(state.scheduleName, 'gym_focused.md');
    expect(store.schedule!.text, contains('# Gym-focused'));
    expect(state.onboarding, isTrue, reason: 'still on the last step');

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(state.onboarding, isFalse);
    expect(find.text('When did you wake up?'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);
    state.dispose();
  });

  testWidgets('first launch with a pasted schedule shows it as your own', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make one with AI'));
    await tester.pumpAndSettle();
    clipboard = workdayText;
    await tester.tap(find.text('Paste schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Start from a template'), findsOneWidget, reason: 'back on the same step');
    expect(find.text('Your own schedule'), findsOneWidget);
    expect(find.text('workday-routine.md'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(state.scheduleName, 'workday-routine.md', reason: 'Continue keeps your own schedule');
    expect(find.text('Two small permissions'), findsOneWidget);
    state.dispose();
  });

  group('import a file', () {
    testWidgets('a valid file is summarised, then used', (tester) async {
      pickScheduleFile = () async => (name: 'my day.md', text: workdayText);
      await launch(tester, firstLaunch: false);
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import file'));
      await tester.pumpAndSettle();

      expect(find.text('Imported file'), findsOneWidget);
      expect(find.text('my day.md'), findsOneWidget);
      expect(find.text('9 blocks · 6 rules · ready to use'), findsOneWidget);
      await tester.tap(find.text('Use this schedule'));
      await tester.pumpAndSettle();
      expect(state.scheduleName, 'my day.md');
      expect(store.schedule!.text, workdayText);
      state.dispose();
    });

    testWidgets('a broken file shows its errors, here and on the schedule file screen', (
      tester,
    ) async {
      pickScheduleFile = () async =>
          (name: 'mine.md', text: sampleText.replaceFirst('right_after: cook', 'right_after: cok'));
      await launch(tester, firstLaunch: false);
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import file'));
      await tester.pumpAndSettle();

      expect(find.text('LINE 15'), findsOneWidget);
      expect(find.text('Choose another file'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      // The previous schedule keeps running; the schedule file screen says why.
      expect(state.scheduleName, 'sample.md');
      expect(find.text('NEW VERSION · LINE 15'), findsOneWidget);
      expect(
        find.textContaining('Your previous schedule keeps running until this is fixed.'),
        findsOneWidget,
      );
      state.dispose();
    });

    testWidgets('a file without a schedule says so', (tester) async {
      pickScheduleFile = () async => (name: 'notes.txt', text: 'Buy milk.');
      await launch(tester, firstLaunch: false);
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import file'));
      await tester.pumpAndSettle();
      expect(find.text('No schedule found'), findsOneWidget);
      expect(find.textContaining('This file has no Enso schedule in it.'), findsOneWidget);

      pickScheduleFile = () async => (name: 'workday.md', text: workdayText);
      await tester.tap(find.text('Choose another file'));
      await tester.pumpAndSettle();
      expect(find.text('workday.md'), findsOneWidget);
      expect(find.text('Use this schedule'), findsOneWidget);
      state.dispose();
    });
  });

  test('every template is listed in the asset bundle', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/templates/'));
    expect(parseSchedule(File('assets/templates/student.md').readAsStringSync()).isValid, isTrue);
  });
}
