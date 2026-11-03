import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../engine/models.dart';
import '../engine/parser.dart';
import '../engine/planner.dart';
import '../services/notifications.dart';
import '../services/reminder_plan.dart';
import 'theme.dart';

/// Temporary built-in schedule until import, templates and onboarding land in
/// step 6.
const String kDemoScheduleAsset = 'assets/demo/sample.md';

/// Test tools (the look switch, the onboarding entry in Settings) exist in
/// debug and profile builds, never in release builds.
const bool kDevTools = !kReleaseMode;

/// Default notification sound (spec § Settings).
const String kDefaultSound = 'Soft chime';

/// The copyable prompt for "Make one with AI". Do not rewrite it.
const String kAiPromptAsset = 'assets/prompts/create_with_ai.md';

/// What the debug-only time-of-day switch is forcing.
enum DebugLook { auto, morning, afternoon, evening, windDown }

/// Today's state: the schedule, the plan and the clock. Kept in memory until
/// persistence arrives in step 5.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({
    DateTime Function()? clock,
    Schedule? initialSchedule,
    NotificationGateway notifications = const NoNotifications(),
  }) : _clock = clock ?? DateTime.now,
       _schedule = initialSchedule,
       _gateway = notifications {
    _now = _clock();
  }

  final NotificationGateway _gateway;
  bool _remindersOff = false;
  Object? _scheduledKey;

  final DateTime Function() _clock;
  Timer? _ticker;

  Schedule? _schedule;
  Plan? _plan;
  late DateTime _now;
  DebugLook _debugLook = DebugLook.auto;
  Set<Cut> _dismissedCuts = {};
  bool _justBuilt = false;
  String? _loadError;
  String _scheduleName = 'sample.md';
  DateTime? _scheduleSince;
  List<ScheduleError> _fileErrors = const [];
  ClockTime? _bedtimeOverride;
  int _headsUpMinutes = 5;
  String _sound = kDefaultSound;

  Schedule? get schedule => _schedule;
  Plan? get plan => _plan;
  DateTime get now => _now;
  String? get loadError => _loadError;

  /// File name of the running schedule.
  String get scheduleName => _scheduleName;

  /// When the running schedule was first used.
  DateTime get scheduleSince => _scheduleSince ?? _now;

  /// Problems with a newer version of the file. The previous schedule keeps
  /// running. Filled by file import in step 6.
  List<ScheduleError> get fileErrors => _fileErrors;

  /// True right after "Build my day", so Today can stagger its rows in once.
  bool get justBuilt => _justBuilt;
  void consumeJustBuilt() => _justBuilt = false;

  /// Reads the bundled schedule and starts the clock.
  Future<void> start() async {
    _scheduleSince ??= _clock();
    if (_schedule == null) {
      final text = await rootBundle.loadString(kDemoScheduleAsset);
      final result = parseSchedule(text);
      _schedule = result.schedule;
      _loadError = result.errors.isEmpty ? null : result.errors.first.message;
    }
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => tick());
    await _gateway.init(onAction: _onNotificationAction);
    _remindersOff = !await _gateway.notificationsEnabled();
    final launch = await _gateway.launchAction();
    if (launch != null) _onNotificationAction(launch);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reminders

  /// Notifications are blocked: Today shows the calm "Reminders are off"
  /// banner.
  bool get remindersOff => _remindersOff;

  /// "Turn on": the Android prompt if it can still be shown, otherwise the
  /// app's notification settings.
  Future<void> turnOnReminders() async {
    final granted = await _gateway.requestNotifications();
    if (!granted) await _gateway.openNotificationSettings();
    await refreshReminderPermission();
  }

  /// Onboarding's "Allow": notifications, then exact alarms (Android 14+).
  Future<void> allowReminders() async {
    await _gateway.requestNotifications();
    await _gateway.requestExactAlarms();
    await refreshReminderPermission();
  }

  Future<void> refreshReminderPermission() async {
    final off = !await _gateway.notificationsEnabled();
    if (off != _remindersOff) {
      _remindersOff = off;
      notifyListeners();
    }
  }

  void _onNotificationAction(String? actionId) {
    // Start just opens Today. +10 min extends the block that is on now.
    if (actionId == kActionPlusTen && _plan != null && current != null) {
      act(const ExtendAction(10));
    }
  }

  /// Every change runs through here; reminders are rescheduled only when the
  /// plan or the reminder settings changed.
  @override
  void notifyListeners() {
    super.notifyListeners();
    _syncReminders();
  }

  void _syncReminders() {
    final plan = checkedIn ? _plan : null;
    final key = (plan, _headsUpMinutes, _sound);
    if (_scheduledKey == key) return;
    _scheduledKey = key;
    final reminders = plan == null
        ? const <Reminder>[]
        : remindersFor(plan, _clock(), headsUpMinutes: _headsUpMinutes);
    unawaited(_gateway.replaceAll(reminders, sound: _sound));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      tick();
      unawaited(refreshReminderPermission());
    }
  }

  /// Moves the clock to now. Called every 15 seconds and on resume.
  void tick() {
    final next = _clock();
    if (next.minute != _now.minute || next.hour != _now.hour || next.day != _now.day) {
      _now = next;
      notifyListeners();
    } else {
      _now = next;
    }
  }

  // ---------------------------------------------------------------------------
  // Day

  /// Start of the app day (04:00) that [t] belongs to.
  static DateTime appDay(DateTime t) {
    final d = DateTime(t.year, t.month, t.day);
    return t.hour < ClockTime.dayStartHour ? DateTime(d.year, d.month, d.day - 1) : d;
  }

  /// Whether today has been checked in.
  bool get checkedIn {
    final p = _plan;
    return p != null && appDay(p.input.wake) == appDay(_now);
  }

  /// Builds the day from the check-in.
  void buildDay({
    required DateTime wake,
    required Set<String> dayTypes,
    required List<Errand> errands,
  }) {
    final s = _schedule;
    if (s == null) return;
    _plan = buildPlan(
      s,
      DayInput(wake: wake, dayTypes: dayTypes, errands: errands, bedtimeOverride: _bedtimeOverride),
    );
    _dismissedCuts = {};
    _justBuilt = true;
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Switches to a schedule that passed the parser (pasted, or made with
  /// AI). Today is rebuilt from the same check-in.
  void useSchedule(Schedule s, {required String name}) {
    _schedule = s;
    _scheduleName = name;
    _scheduleSince = _clock();
    _fileErrors = const [];
    _loadError = null;
    final p = _plan;
    if (p != null && checkedIn) {
      _plan = buildPlan(
        s,
        DayInput(
          wake: p.input.wake,
          dayTypes: p.input.dayTypes.intersection(s.dayTypes.toSet()),
          errands: p.input.errands,
          bedtimeOverride: _bedtimeOverride,
        ),
      );
      _dismissedCuts = {};
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Settings (in memory until step 5)

  /// Local bedtime override. Null uses the file's bedtime.
  ClockTime? get bedtimeOverride => _bedtimeOverride;

  /// The bedtime in effect.
  ClockTime? get bedtime => _bedtimeOverride ?? _schedule?.bedtime;

  /// Sets the bedtime. Choosing the file's own bedtime clears the override.
  /// Today re-plans straight away.
  void setBedtime(ClockTime? t) {
    _bedtimeOverride = t == _schedule?.bedtime ? null : t;
    final p = _plan;
    final s = _schedule;
    if (p != null && s != null) {
      _plan = buildPlan(s, p.input.withBedtimeOverride(_bedtimeOverride));
    }
    notifyListeners();
  }

  /// Minutes of heads-up before a block ends.
  int get headsUpMinutes => _headsUpMinutes;
  void setHeadsUpMinutes(int m) {
    _headsUpMinutes = m;
    notifyListeners();
  }

  /// Notification sound name.
  String get sound => _sound;
  void setSound(String name) {
    _sound = name;
    notifyListeners();
  }

  /// Applies a block action now and re-plans.
  void act(PlanAction action) {
    final p = _plan;
    if (p == null) return;
    _now = _clock();
    _plan = applyAction(p, action, _now);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// What [action] would change, as one sentence. Null if nothing else moves.
  String? preview(PlanAction action, String subjectId) {
    final p = _plan;
    if (p == null) return null;
    return describePreview(action, previewAction(p, action, _clock()), subjectId: subjectId);
  }

  /// Cuts the summary card shows. Empty once dismissed, until they change.
  List<Cut> get visibleCuts {
    final cuts = _plan?.cuts ?? const <Cut>[];
    if (cuts.isEmpty || cuts.toSet().difference(_dismissedCuts).isEmpty) return const [];
    return cuts;
  }

  void dismissSummary() {
    _dismissedCuts = {...?_plan?.cuts};
    notifyListeners();
  }

  /// The block running now.
  PlannedBlock? get current => _plan?.blockAt(_now);

  /// The first block that starts after now.
  PlannedBlock? get next {
    final p = _plan;
    if (p == null) return null;
    for (final b in p.blocks) {
      if (b.start.isAfter(_now)) return b;
    }
    return null;
  }

  /// The block the hero card shows: the one running now, or the next one
  /// during a gap.
  PlannedBlock? get focus => current ?? next;

  /// The block after [focus], for the "Up next" row. Null at the end of the day.
  PlannedBlock? get upNext {
    final p = _plan;
    final f = focus;
    if (p == null || f == null) return null;
    final i = p.blocks.indexWhere((b) => b.id == f.id);
    return i + 1 < p.blocks.length ? p.blocks[i + 1] : null;
  }

  /// After the last block has started, the screen dims to the night view.
  bool get isWindDown {
    if (_debugLook == DebugLook.windDown) return true;
    if (_debugLook != DebugLook.auto) return false;
    final p = _plan;
    if (p == null || p.blocks.isEmpty || !checkedIn) return false;
    return !_now.isBefore(p.blocks.last.start);
  }

  // ---------------------------------------------------------------------------
  // Ambience

  Ambience get ambience => switch (_debugLook) {
    DebugLook.morning => Ambience.morning,
    DebugLook.afternoon => Ambience.afternoon,
    DebugLook.evening || DebugLook.windDown => Ambience.evening,
    DebugLook.auto => Ambience.at(_now),
  };

  DebugLook get debugLook => _debugLook;

  /// Debug builds only: cycles auto → morning → afternoon → evening → wind
  /// down → auto.
  void cycleDebugLook() {
    if (!kDevTools) return;
    _debugLook = DebugLook.values[(_debugLook.index + 1) % DebugLook.values.length];
    HapticFeedback.selectionClick();
    notifyListeners();
  }
}

/// Makes [AppState] available below it.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads without listening, for callbacks.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
