import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../engine/models.dart';
import '../app_state.dart';
import '../routes.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ambience.dart';
import '../widgets/hero_text.dart';
import '../widgets/line_icon.dart';
import '../widgets/morph_hero.dart';
import '../widgets/surfaces.dart';
import '../widgets/timeline.dart';
import 'block_sheet.dart';
import 'check_in_screen.dart';
import 'settings_screen.dart';

/// Hero tag shared by "Check in", "Build my day" and the hero card.
const String kDayCardTag = 'day-card';

/// Hero tag for the hero card's block name.
String heroCardTag(String blockId) => 'hero-$blockId';

/// The main screen, in four states: before check-in, the day (normal or
/// shortened), and wind down.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final Widget body;
    final String key;
    if (state.isWindDown) {
      body = const _WindDown();
      key = 'wind-down';
    } else if (!state.checkedIn || state.plan == null) {
      body = const _BeforeCheckIn();
      key = 'before';
    } else {
      body = const _Day();
      key = 'day';
    }
    return AnimatedSwitcher(
      // The night view dims in slowly; check-in → day follows the hero morph.
      duration: key == 'wind-down' ? Springs.ambience : Motion.checkInDuration,
      // The outgoing view must not offer heroes: both views can hold the
      // "day card" tag while they cross-fade.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [
          for (final p in previous) HeroMode(enabled: false, child: p),
          ?current,
        ],
      ),
      child: KeyedSubtree(key: ValueKey(key), child: body),
    );
  }
}

/// Date and "Today", with the settings button. In debug builds a long press on
/// the title cycles the time-of-day look.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = EnsoPalette.of(context);
    final debug = kDebugMode && state.debugLook != DebugLook.auto;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: kDebugMode ? state.cycleDebugLook : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateLabel(state.now), style: EnsoType.label.copyWith(color: p.ink2)),
                  const SizedBox(height: 2),
                  Text(
                    debug ? 'Today · ${state.debugLook.name}' : 'Today',
                    style: EnsoType.title.copyWith(color: p.ink),
                  ),
                ],
              ),
            ),
          ),
          IconAction(
            icon: LineIcons.settings,
            label: 'Settings',
            onTap: () => pushScreen<void>(context, const SettingsScreen()),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// The day

class _Day extends StatefulWidget {
  const _Day();

  @override
  State<_Day> createState() => _DayState();
}

class _DayState extends State<_Day> {
  late bool _stagger;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _stagger = state.justBuilt;
    state.consumeJustBuilt();
  }

  void _open(PlannedBlock b, String tag) => showBlockSheet(context, blockId: b.id, heroTag: tag);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = EnsoPalette.of(context);
    final plan = state.plan!;
    final focus = state.focus;
    final cuts = state.visibleCuts;
    final hasNotes = cuts.isNotEmpty || plan.overflowMinutes > 0;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          if (focus != null) ...[
            const SizedBox(height: 16),
            _HeroCard(
              block: focus,
              now: state.now,
              onTap: () => _open(focus, heroCardTag(focus.id)),
              fadeIn: _stagger,
            ),
            const SizedBox(height: 12),
            _UpNext(block: state.upNext, bedtime: plan.bedtime),
          ],
          AnimatedSize(
            duration: Motion.replanDuration,
            curve: Motion.replan,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cuts.isNotEmpty)
                  _Summary(plan: plan, cuts: cuts, onClose: state.dismissSummary),
                if (plan.overflowMinutes > 0) _OverflowNote(minutes: plan.overflowMinutes),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, hasNotes ? 20 : 24, 12, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your day', style: EnsoType.label.copyWith(color: p.ink2)),
                TextAction(
                  label: 'Running late?',
                  icon: LineIcons.clock,
                  onTap: () => state.act(const RunningLateAction()),
                ),
              ],
            ),
          ),
          Expanded(
            child: Timeline(
              plan: plan,
              now: state.now,
              stagger: _stagger,
              fadeFrom: hasNotes ? 0.55 : 0.65,
              onTap: _open,
            ),
          ),
        ],
      ),
    );
  }
}

/// The current block: name, detail, time range, category and a slow ring.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.block,
    required this.now,
    required this.onTap,
    required this.fadeIn,
  });

  final PlannedBlock block;
  final DateTime now;
  final VoidCallback onTap;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final def = block.block;
    final running = !now.isBefore(block.start);
    final total = block.end.difference(block.start).inSeconds;
    final progress = running && total > 0 ? now.difference(block.start).inSeconds / total : 0.0;
    final left = minutesBetween(now, running ? block.end : block.start);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Overline(
                    running ? 'Now' : 'Up next',
                    dot: running,
                    color: running ? p.accentInk : p.ink2,
                  ),
                  const SizedBox(height: 8),
                  HeroText(
                    tag: heroCardTag(def.id),
                    text: def.name,
                    style: EnsoType.hero.copyWith(color: p.ink),
                  ),
                  if (def.detail != null) ...[
                    const SizedBox(height: 8),
                    Text(def.detail!, style: EnsoType.body.copyWith(color: p.ink2, height: 1.3)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            ProgressRing(
              progress: progress,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatDuration(left), style: EnsoType.ring.copyWith(color: p.ink)),
                  Text(
                    running ? 'left' : 'to go',
                    style: EnsoType.caption.copyWith(fontSize: 12, color: p.ink2, height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RollingText(
              rangeLabel(block.start, block.end),
              style: EnsoType.time.copyWith(color: p.ink2),
            ),
            Text(categoryLabel(def.category), style: EnsoType.time.copyWith(color: p.ink2)),
          ],
        ),
      ],
    );
    if (fadeIn) content = _FadeInOnce(child: content);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Semantics(
        button: true,
        label:
            '${running ? 'Now' : 'Up next'}, ${def.name}, ${formatDuration(left)} ${running ? 'left' : 'to go'}',
        child: Pressable(
          onTap: onTap,
          haptic: false,
          // The morph wraps only the glass shape: a Hero can't contain the
          // block name's own Hero.
          child: Stack(
            children: [
              Positioned.fill(
                child: MorphHero(
                  tag: kDayCardTag,
                  color: p.surface,
                  radius: Radii.hero,
                  child: const Glass(radius: Radii.hero, shadow: true, child: SizedBox.expand()),
                ),
              ),
              Padding(padding: const EdgeInsets.all(Space.lg), child: content),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeInOnce extends StatelessWidget {
  const _FadeInOnce({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Motion.checkInDuration,
    curve: Motion.checkIn,
    builder: (context, v, child) => Opacity(opacity: v.clamp(0, 1), child: child),
    child: child,
  );
}

/// "Up next" row, tinted with the next block's category.
class _UpNext extends StatelessWidget {
  const _UpNext({required this.block, required this.bedtime});

  final PlannedBlock? block;
  final DateTime bedtime;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final b = block;
    final name = b?.block.name ?? 'Lights out';
    final time = b?.start ?? bedtime;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: AnimatedContainer(
        duration: Motion.replanDuration,
        curve: Motion.replan,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: p.tint(b?.block.category ?? Category.rest),
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Up next', style: EnsoType.label.copyWith(fontSize: 12, color: p.ink2)),
                  const SizedBox(height: 2),
                  Text(name, style: EnsoType.bodyStrong.copyWith(color: p.ink)),
                ],
              ),
            ),
            RollingText(
              formatClock(time),
              style: EnsoType.bodyStrong.copyWith(fontWeight: FontWeight.w400, color: p.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet card listing what got shorter. No red, no warnings.
class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.cuts, required this.onClose});

  final Plan plan;
  final List<Cut> cuts;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final rowStyle = EnsoType.bodySmall.copyWith(
      fontSize: 14,
      height: 1.3,
      color: p.ink,
      fontFeatures: EnsoType.tabular,
    );
    return Glass(
      tone: GlassTone.sunk,
      radius: Radii.small,
      margin: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    summaryMessage(plan, cuts),
                    style: EnsoType.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: p.ink,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -8),
                child: IconAction(
                  icon: LineIcons.close,
                  label: 'Dismiss',
                  size: 18,
                  box: 40,
                  color: p.ink3,
                  onTap: onClose,
                ),
              ),
            ],
          ),
          for (final c in cuts) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Expanded(child: Text(_name(plan, c.blockId), style: rowStyle)),
                  Text(_change(c), style: rowStyle.copyWith(color: p.ink2)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _name(Plan plan, String id) =>
      plan.schedule.blockById(id)?.name ?? plan.blockById(id)?.block.name ?? id;

  static String _change(Cut c) => c.dropped
      ? '${formatDuration(c.fromMinutes)} → left out'
      : '${formatDuration(c.fromMinutes)} → ${formatDuration(c.toMinutes)}';
}

/// "You started at 07:40, so two blocks are a little shorter today."
String summaryMessage(Plan plan, List<Cut> cuts) {
  final shorter = cuts.where((c) => !c.dropped).length;
  final left = cuts.length - shorter;
  String n(int count, String one, String many) =>
      count == 1 ? 'one $one' : '${numberWords(count)} $many';
  String verb(int count) => count == 1 ? 'is' : 'are';

  final String what;
  if (left == 0) {
    what = '${n(shorter, 'block', 'blocks')} ${verb(shorter)} a little shorter today.';
  } else if (shorter == 0) {
    what = '${n(left, 'block', 'blocks')} ${verb(left)} left out today.';
  } else {
    what =
        '${n(shorter, 'block', 'blocks')} ${verb(shorter)} a little shorter '
        'and ${numberWords(left)} ${verb(left)} left out today.';
  }
  final lead = plan.input.now == null
      ? 'You started at ${formatClock(plan.input.wake)}, so '
      : 'To fit the rest of the day, ';
  return '$lead$what';
}

/// The day can't fit even after every allowed cut. Calm, no colour change.
class _OverflowNote extends StatelessWidget {
  const _OverflowNote({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Glass(
      tone: GlassTone.sunk,
      radius: Radii.small,
      margin: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Text(
        'Today runs ${formatDuration(minutes)} past lights out. '
        'Everything that can shrink already has.',
        style: EnsoType.bodySmall.copyWith(fontWeight: FontWeight.w500, height: 1.45, color: p.ink),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Before check-in

class _BeforeCheckIn extends StatelessWidget {
  const _BeforeCheckIn();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = EnsoPalette.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.ambience.greeting, style: EnsoType.greeting.copyWith(color: p.ink)),
                  const SizedBox(height: 12),
                  Text('When did you wake up?', style: EnsoType.subheading.copyWith(color: p.ink2)),
                ],
              ),
            ),
          ),
          if (state.loadError != null)
            Glass(
              tone: GlassTone.sunk,
              radius: Radii.small,
              margin: const EdgeInsets.symmetric(horizontal: Space.md),
              padding: const EdgeInsets.all(20),
              child: Text(state.loadError!, style: EnsoType.bodySmall.copyWith(color: p.ink)),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.bottomInset(context)),
            child: MorphHero(
              tag: kDayCardTag,
              color: p.accent,
              radius: 30,
              showContentInFlight: true,
              child: PrimaryButton(
                label: 'Check in',
                onTap: state.schedule == null
                    ? null
                    : () => pushScreen<void>(context, const CheckInScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Wind down

class _WindDown extends StatelessWidget {
  const _WindDown();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = EnsoPalette.of(context);
    final schedule = state.schedule;
    final now = state.now;
    final day = AppState.appDay(now);
    final bedtime =
        state.plan?.bedtime ??
        (schedule == null
            ? now
            : DateTime(day.year, day.month, day.day, 0, schedule.bedtime.dayMinutes));
    final wakeTarget = schedule?.wakeTarget ?? const ClockTime(6, 0);
    final wakeAt = DateTime(day.year, day.month, day.day + 1, wakeTarget.hour, wakeTarget.minute);
    final sleep = wakeAt.difference(bedtime).inMinutes;
    final left = minutesBetween(now, bedtime);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: kDebugMode ? state.cycleDebugLook : null,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LineIcon(LineIcons.moon, size: 32, color: p.ink2),
                    const SizedBox(height: 28),
                    Text(
                      'Lights out at',
                      style: EnsoType.body.copyWith(color: p.ink2, height: 1.2),
                    ),
                    const SizedBox(height: 10),
                    Text(formatClock(bedtime), style: EnsoType.clock.copyWith(color: p.ink)),
                    const SizedBox(height: 10),
                    Text(
                      windDownLine(left),
                      style: EnsoType.body.copyWith(fontSize: 18, color: p.ink2),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.bottomInset(context) + 8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: p.nightCard,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tomorrow', style: EnsoType.label.copyWith(color: p.ink2)),
                        const SizedBox(height: 4),
                        Text(
                          'Wake around $wakeTarget',
                          style: EnsoType.bodyStrong.copyWith(
                            color: p.ink,
                            fontFeatures: EnsoType.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${sleepLabel(sleep)} of sleep',
                    style: EnsoType.time.copyWith(color: p.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Twenty quiet minutes left. The day is done."
String windDownLine(int minutesLeft) {
  if (minutesLeft <= 0) return 'Past lights out. Sleep well.';
  if (minutesLeft == 1) return 'One quiet minute left. The day is done.';
  if (minutesLeft < 60) {
    return '${capitalise(numberWords(minutesLeft))} quiet minutes left. The day is done.';
  }
  return '${formatDuration(minutesLeft)} of quiet left. The day is done.';
}
