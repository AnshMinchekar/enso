import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:enso/services/storage.dart';
import 'package:enso/ui/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String sampleText = File('test/fixtures/sample.md').readAsStringSync();
final String workdayText = File('test/fixtures/workday.md').readAsStringSync();
DateTime at(int h, int m, {int day = 26}) => DateTime(2026, 10, day, h, m);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceStore', () {
    late Directory dir;
    late DeviceStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('enso_store');
      store = DeviceStore(directory: () async => dir);
    });
    tearDown(() => dir.delete(recursive: true));

    test('schedule file is kept in the documents directory', () async {
      expect(await store.loadSchedule(), isNull);
      await store.saveSchedule(
        StoredSchedule(name: 'anshs-routine.md', text: sampleText, since: at(9, 0)),
      );
      expect(File('${dir.path}/schedules/anshs-routine.md').readAsStringSync(), sampleText);
      final back = (await store.loadSchedule())!;
      expect(back.name, 'anshs-routine.md');
      expect(back.text, sampleText);
      expect(back.since, at(9, 0));
    });

    test('unsafe file names stay inside the schedules folder', () async {
      await store.saveSchedule(StoredSchedule(name: '../x/y.md', text: 'a', since: at(9, 0)));
      expect(Directory('${dir.path}/schedules').listSync(), hasLength(1));
      expect((await store.loadSchedule())!.text, 'a');
    });

    test('today is saved, read back and cleared', () async {
      await store.saveDay({'day': 'x', 'n': 1});
      expect(await store.loadDay(), {'day': 'x', 'n': 1});
      await store.saveDay(null);
      expect(await store.loadDay(), isNull);
    });

    test('settings live in shared_preferences', () async {
      expect((await store.loadSettings()).headsUpMinutes, 5);
      await store.saveSettings(
        const StoredSettings(
          bedtimeOverride: ClockTime(23, 0),
          headsUpMinutes: 10,
          sound: 'Silent',
        ),
      );
      final s = await store.loadSettings();
      expect(s.bedtimeOverride, const ClockTime(23, 0));
      expect(s.headsUpMinutes, 10);
      expect(s.sound, 'Silent');
      await store.saveSettings(const StoredSettings());
      expect((await store.loadSettings()).bedtimeOverride, isNull);
    });
  });

  group('restarting the app', () {
    late DateTime now;
    late MemoryStore store;

    Future<AppState> launch() async {
      final s = AppState(clock: () => now, store: store);
      await s.start();
      return s;
    }

    setUp(() {
      now = at(6, 16);
      store = MemoryStore();
    });

    test('today, its actions and the settings come back', () async {
      var app = await launch();
      app.setHeadsUpMinutes(10);
      app.setSound('Silent');
      app.setBedtime(const ClockTime(23, 0));
      app.buildDay(wake: at(6, 15), dayTypes: {'gym'}, errands: const [Errand('Haircut', 60)]);
      now = at(12, 0);
      app.tick();
      app.act(const ExtendAction(15));
      app.act(const SkipAction('gaming'));
      final before = app.plan!;
      app.dispose();
      await Future<void>.delayed(Duration.zero);

      now = at(12, 30);
      app = await launch();
      expect(app.checkedIn, isTrue);
      final after = app.plan!;
      expect(
        after.blocks.map((b) => (b.id, b.start, b.end)),
        before.blocks.map((b) => (b.id, b.start, b.end)),
      );
      expect(after.cuts, before.cuts);
      expect(after.blockById('gaming'), isNull);
      expect(after.blockById('errand_1')!.block.name, 'Haircut');
      expect(app.headsUpMinutes, 10);
      expect(app.sound, 'Silent');
      expect(app.bedtimeOverride, const ClockTime(23, 0));
      app.dispose();
    });

    test('a dismissed summary stays dismissed', () async {
      now = at(8, 0);
      var app = await launch();
      app.buildDay(wake: at(7, 55), dayTypes: {'gym', 'cook'}, errands: const []);
      expect(app.visibleCuts, isNotEmpty);
      app.dismissSummary();
      app.dispose();
      await Future<void>.delayed(Duration.zero);
      app = await launch();
      expect(app.plan!.cuts, isNotEmpty);
      expect(app.visibleCuts, isEmpty);
      app.dispose();
    });

    test('a new day starts at check-in again', () async {
      var app = await launch();
      app.buildDay(wake: at(6, 15), dayTypes: {'gym'}, errands: const []);
      app.dispose();
      await Future<void>.delayed(Duration.zero);
      now = at(7, 0, day: 27);
      app = await launch();
      expect(app.checkedIn, isFalse);
      app.dispose();
    });

    test('a pasted schedule is the one running after a restart', () async {
      var app = await launch();
      app.useSchedule(
        parseSchedule(workdayText).schedule!,
        name: 'workday-routine.md',
        text: workdayText,
      );
      app.dispose();
      await Future<void>.delayed(Duration.zero);
      app = await launch();
      expect(app.scheduleName, 'workday-routine.md');
      expect(app.schedule!.bedtime, const ClockTime(23, 0));
      expect(app.scheduleSince, at(6, 16));
      app.dispose();
    });

    test('a saved file that no longer parses shows its errors and keeps the app usable', () async {
      store.schedule = StoredSchedule(
        name: 'mine.md',
        text: sampleText.replaceFirst('right_after: cook', 'right_after: cok'),
        since: at(6, 0),
      );
      final app = await launch();
      expect(app.fileErrors.single.line, 15);
      expect(app.schedule, isNotNull, reason: 'falls back instead of leaving the app empty');
      app.dispose();
    });
  });
}
