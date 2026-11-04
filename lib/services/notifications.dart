import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// The notification channel's name, as Settings → Notifications shows it.
const String kChannelName = 'Enso';

/// Android notification channels can't change sound after they are created,
/// so each sound gets its own channel (all named "Enso").
String channelIdFor(String sound) => sound == 'Silent' ? 'enso_silent' : 'enso_soft_chime';

/// What Enso needs from the notification system. A fake stands in for it in
/// tests and on platforms without notifications.
abstract class NotificationGateway {
  /// [onAction] receives the action id ([kActionStart], [kActionPlusTen])
  /// or null for a plain tap.
  Future<void> init({required void Function(String? actionId) onAction});

  /// The action that launched the app from a notification, if any.
  Future<String?> launchAction();

  Future<bool> notificationsEnabled();

  /// Shows the Android 13+ permission prompt. True if granted.
  Future<bool> requestNotifications();

  /// Android 14+: opens the exact-alarm settings page if not yet allowed.
  Future<void> requestExactAlarms();

  /// Opens this app's notification settings, for when the prompt can no
  /// longer be shown.
  Future<void> openNotificationSettings();

  /// Cancels everything and schedules [reminders] on the channel for [sound].
  Future<void> replaceAll(List<Reminder> reminders, {required String sound});
}

/// Does nothing. Used where notifications aren't available.
class NoNotifications implements NotificationGateway {
  const NoNotifications();

  @override
  Future<void> init({required void Function(String? actionId) onAction}) async {}

  @override
  Future<String?> launchAction() async => null;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Future<void> requestExactAlarms() async {}

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> replaceAll(List<Reminder> reminders, {required String sound}) async {}
}

/// `flutter_local_notifications` on Android.
class LocalNotifications implements NotificationGateway {
  LocalNotifications();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const MethodChannel _settings = MethodChannel('enso/settings');

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init({required void Function(String? actionId) onAction}) async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // Scheduling uses absolute instants, so UTC still fires on time.
      debugPrint('Enso: local time zone unavailable ($e), using UTC');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_enso'),
      ),
      onDidReceiveNotificationResponse: (r) => onAction(r.actionId),
    );
  }

  @override
  Future<String?> launchAction() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.actionId ?? kActionStart;
  }

  @override
  Future<bool> notificationsEnabled() async => await _android?.areNotificationsEnabled() ?? true;

  @override
  Future<bool> requestNotifications() async =>
      await _android?.requestNotificationsPermission() ?? true;

  @override
  Future<void> requestExactAlarms() async {
    final android = _android;
    if (android == null) return;
    if (await android.canScheduleExactNotifications() ?? true) return;
    await android.requestExactAlarmsPermission();
  }

  @override
  Future<void> openNotificationSettings() async {
    try {
      await _settings.invokeMethod<void>('openNotificationSettings');
    } on PlatformException catch (e) {
      debugPrint('Enso: could not open notification settings ($e)');
    }
  }

  AndroidNotificationChannel _channel(String sound) {
    final silent = sound == 'Silent';
    return AndroidNotificationChannel(
      channelIdFor(sound),
      kChannelName,
      description: 'When a block ends and what comes next.',
      playSound: !silent,
      sound: silent ? null : const RawResourceAndroidNotificationSound('soft_chime'),
    );
  }

  @override
  Future<void> replaceAll(List<Reminder> reminders, {required String sound}) async {
    final android = _android;
    if (android == null) return;
    final channel = _channel(sound);
    // One calm channel at a time: remove the one for the other sound.
    for (final other in ['Soft chime', 'Silent']) {
      if (channelIdFor(other) != channel.id) {
        await android.deleteNotificationChannel(channelId: channelIdFor(other));
      }
    }
    await android.createNotificationChannel(channel);
    await _plugin.cancelAll();

    final exact = await android.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.blockId,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        androidScheduleMode: mode,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            playSound: channel.playSound,
            sound: channel.sound,
            icon: 'ic_stat_enso',
            category: AndroidNotificationCategory.reminder,
            actions: r.hasActions
                ? const [
                    AndroidNotificationAction(kActionStart, 'Start', showsUserInterface: true),
                    AndroidNotificationAction(kActionPlusTen, '+10 min', showsUserInterface: true),
                  ]
                : null,
          ),
        ),
      );
    }
  }
}
