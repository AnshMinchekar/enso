import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/models.dart';

/// The schedule file in use, exactly as it was imported, pasted or chosen.
class StoredSchedule {
  const StoredSchedule({required this.name, required this.text, required this.since});

  final String name;
  final String text;

  /// When it was first used ("Running since 24 Oct").
  final DateTime since;
}

/// Settings kept on this phone.
class StoredSettings {
  const StoredSettings({this.bedtimeOverride, this.headsUpMinutes = 5, this.sound = 'Soft chime'});

  final ClockTime? bedtimeOverride;
  final int headsUpMinutes;
  final String sound;
}

/// Where Enso keeps things between launches.
abstract class Store {
  Future<StoredSchedule?> loadSchedule();
  Future<void> saveSchedule(StoredSchedule schedule);

  /// Today's saved state, or null.
  Future<Map<String, Object?>?> loadDay();

  /// Saves today's state; null clears it.
  Future<void> saveDay(Map<String, Object?>? day);

  Future<StoredSettings> loadSettings();
  Future<void> saveSettings(StoredSettings settings);
}

/// Keeps nothing. The default in tests that don't care about storage.
class NoStore implements Store {
  const NoStore();

  @override
  Future<StoredSchedule?> loadSchedule() async => null;
  @override
  Future<void> saveSchedule(StoredSchedule schedule) async {}
  @override
  Future<Map<String, Object?>?> loadDay() async => null;
  @override
  Future<void> saveDay(Map<String, Object?>? day) async {}
  @override
  Future<StoredSettings> loadSettings() async => const StoredSettings();
  @override
  Future<void> saveSettings(StoredSettings settings) async {}
}

/// Keeps everything in memory, for tests that restart the app.
class MemoryStore implements Store {
  StoredSchedule? schedule;
  Map<String, Object?>? day;
  StoredSettings settings = const StoredSettings();

  @override
  Future<StoredSchedule?> loadSchedule() async => schedule;
  @override
  Future<void> saveSchedule(StoredSchedule s) async => schedule = s;
  @override
  Future<Map<String, Object?>?> loadDay() async =>
      day == null ? null : (jsonDecode(jsonEncode(day)) as Map).cast<String, Object?>();
  @override
  Future<void> saveDay(Map<String, Object?>? d) async => day = d;
  @override
  Future<StoredSettings> loadSettings() async => settings;
  @override
  Future<void> saveSettings(StoredSettings s) async => settings = s;
}

/// On the phone: the schedule file and today's state in the app documents
/// directory (`path_provider`), settings in `shared_preferences`.
class DeviceStore implements Store {
  DeviceStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  static const _kScheduleName = 'schedule.name';
  static const _kScheduleSince = 'schedule.since';
  static const _kBedtime = 'settings.bedtime';
  static const _kHeadsUp = 'settings.headsUp';
  static const _kSound = 'settings.sound';

  Future<File> _scheduleFile(String name) async =>
      File('${(await _directory()).path}/schedules/${_safeName(name)}');

  Future<File> _dayFile() async => File('${(await _directory()).path}/today.json');

  /// File names come from headings and pickers: keep them to one safe path
  /// segment.
  static String _safeName(String name) {
    final s = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '-').trim();
    return s.isEmpty ? 'schedule.md' : s;
  }

  /// Writes to a temporary file first, so a crash never leaves half a file.
  static Future<void> _write(File f, String text) async {
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<StoredSchedule?> loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kScheduleName);
    if (name == null) return null;
    final file = await _scheduleFile(name);
    if (!await file.exists()) return null;
    final since = DateTime.tryParse(prefs.getString(_kScheduleSince) ?? '') ?? DateTime.now();
    return StoredSchedule(name: name, text: await file.readAsString(), since: since);
  }

  @override
  Future<void> saveSchedule(StoredSchedule s) async {
    await _write(await _scheduleFile(s.name), s.text);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kScheduleName, _safeName(s.name));
    await prefs.setString(_kScheduleSince, s.since.toIso8601String());
  }

  @override
  Future<Map<String, Object?>?> loadDay() async {
    final f = await _dayFile();
    if (!await f.exists()) return null;
    try {
      return (jsonDecode(await f.readAsString()) as Map).cast<String, Object?>();
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveDay(Map<String, Object?>? day) async {
    final f = await _dayFile();
    if (day == null) {
      if (await f.exists()) await f.delete();
      return;
    }
    await _write(f, jsonEncode(day));
  }

  @override
  Future<StoredSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return StoredSettings(
      bedtimeOverride: ClockTime.tryParse(prefs.getString(_kBedtime) ?? ''),
      headsUpMinutes: prefs.getInt(_kHeadsUp) ?? 5,
      sound: prefs.getString(_kSound) ?? 'Soft chime',
    );
  }

  @override
  Future<void> saveSettings(StoredSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    final b = s.bedtimeOverride;
    if (b == null) {
      await prefs.remove(_kBedtime);
    } else {
      await prefs.setString(_kBedtime, b.toString());
    }
    await prefs.setInt(_kHeadsUp, s.headsUpMinutes);
    await prefs.setString(_kSound, s.sound);
  }
}
