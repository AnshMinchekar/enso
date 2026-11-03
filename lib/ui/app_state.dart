import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../engine/models.dart';
import '../engine/parser.dart';
import '../engine/planner.dart';
import 'theme.dart';

/// Temporary built-in schedule until import, templates and onboarding land in
/// step 6.
const String kDemoScheduleAsset = 'assets/demo/sample.md';

/// What the debug-only time-of-day switch is forcing.
enum DebugLook { auto, morning, afternoon, evening, windDown }

/// Today's state: the schedule, the plan and the clock. Kept in memory until
/// persistence arrives in step 5.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({DateTime Function()? clock, Schedule? initialSchedule})
    : _clock = clock ?? DateTime.now,
      _schedule = initialSchedule {
    _now = _clock();
  }

  final DateTime Function() _clock;
  Timer? _ticker;

  Schedule? _schedule;
  Plan? _plan;
  late DateTime _now;
  DebugLook _debugLook = DebugLook.auto;
  Set<Cut> _dismissedCuts = {};
  bool _justBuilt = false;
  String? _loadError;

  Schedule? get schedule => _schedule;
  Plan? get plan => _plan;
  DateTime get now => _now;
  String? get loadError => _loadError;

  /// True right after "Build my day", so Today can stagger its rows in once.
  bool get justBuilt => _justBuilt;
  void consumeJustBuilt() => _justBuilt = false;

  /// Reads the bundled schedule and starts the clock.
  Future<void> start() async {
    if (_schedule == null) {
      final text = await rootBundle.loadString(kDemoScheduleAsset);
      final result = parseSchedule(text);
      _schedule = result.schedule;
      _loadError = result.errors.isEmpty ? null : result.errors.first.message;
    }
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => tick());
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) tick();
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
    _plan = buildPlan(s, DayInput(wake: wake, dayTypes: dayTypes, errands: errands));
    _dismissedCuts = {};
    _justBuilt = true;
    HapticFeedback.mediumImpact();
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
    if (!kDebugMode) return;
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
