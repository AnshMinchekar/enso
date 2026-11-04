import 'dart:io';

import 'package:enso/engine/models.dart';
import 'package:enso/engine/parser.dart';
import 'package:enso/services/notifications.dart';
import 'package:enso/services/reminder_plan.dart';
import 'package:enso/ui/app.dart';
import 'package:enso/ui/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int h, int m) => DateTime(2026, 10, 26, h, m);
final Schedule sample = parseSchedule(File('test/fixtures/sample.md').readAsStringSync()).schedule!;

class FakeGateway implements NotificationGateway {
  bool enabled = true;
  bool grantOnRequest = false;
  int openedSettings = 0;
  int exactRequests = 0;
  String? launch;
  void Function(String?)? onAction;
  final List<(List<Reminder>, String)> scheduled = [];

  @override
  Future<void> init({required void Function(String? actionId) onAction}) async =>
      this.onAction = onAction;
  @override
  Future<String?> launchAction() async => launch;
  @override
  Future<bool> notificationsEnabled() async => enabled;
  @override
  Future<bool> requestNotifications() async {
    if (grantOnRequest) enabled = true;
    return enabled;
  }

  @override
  Future<void> requestExactAlarms() async => exactRequests++;
  @override
  Future<void> openNotificationSettings() async => openedSettings++;
  @override
  Future<void> replaceAll(List<Reminder> reminders, {required String sound}) async =>
      scheduled.add((reminders, sound));
}

void main() {
  late DateTime now;
  late FakeGateway gateway;
  late AppState state;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    state = AppState(clock: () => now, initialSchedule: sample, notifications: gateway);
    await state.start();
    await tester.pumpWidget(EnsoApp(state: state));
    await tester.pumpAndSettle();
  }

  setUp(() {
    now = at(6, 16);
    gateway = FakeGateway();
  });

  testWidgets('building the day schedules reminders; actions and settings reschedule', (
    tester,
  ) async {
    await pump(tester);
    state.buildDay(wake: at(6, 15), dayTypes: {'gym'}, errands: const []);
    await tester.pumpAndSettle();
    var (reminders, sound) = gateway.scheduled.last;
    expect(sound, 'Soft chime');
    expect(reminders.first.body, 'Breakfast, until 06:40. Next, Language practice.');

    // +10 min from a notification extends the block that is on now.
    now = at(6, 30);
    state.tick();
    final count = gateway.scheduled.length;
    gateway.onAction!(kActionPlusTen);
    await tester.pumpAndSettle();
    expect(state.plan!.blockById('breakfast')!.end, at(6, 50));
    expect(gateway.scheduled.length, count + 1);
    final nextStart = gateway.scheduled.last.$1.firstWhere(
      (r) => r.kind == ReminderKind.blockStart,
    );
    expect(nextStart.body, startsWith('Language practice, until'));
    expect(nextStart.at, at(6, 50));

    // Start only opens the app.
    final plan = state.plan;
    gateway.onAction!(kActionStart);
    expect(identical(state.plan, plan), isTrue);

    state.setHeadsUpMinutes(10);
    state.setSound('Silent');
    (reminders, sound) = gateway.scheduled.last;
    expect(sound, 'Silent');
    expect(
      reminders.where((r) => r.kind == ReminderKind.headsUp).first.body,
      startsWith('10 minutes left in'),
    );
    state.dispose();
  });

  testWidgets('reminders off: the banner shows, and Turn on falls back to settings', (
    tester,
  ) async {
    gateway.enabled = false;
    await pump(tester);
    expect(find.text('Reminders are off'), findsOneWidget);
    expect(find.text('You’ll only see changes while the app is open.'), findsOneWidget);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(gateway.openedSettings, 1, reason: 'the prompt was refused, so settings open');

    gateway.grantOnRequest = true;
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(find.text('Reminders are off'), findsNothing);
    state.dispose();
  });

  testWidgets('onboarding Allow asks for notifications and exact alarms', (tester) async {
    gateway.grantOnRequest = true;
    await pump(tester);
    await state.allowReminders();
    expect(gateway.exactRequests, 1);
    expect(state.remindersOff, isFalse);
    state.dispose();
  });
}
