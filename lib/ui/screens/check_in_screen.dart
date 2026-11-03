import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../engine/models.dart';
import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/line_icon.dart';
import '../widgets/morph_hero.dart';
import '../widgets/surfaces.dart';
import '../widgets/wake_picker.dart';
import 'block_sheet.dart';
import 'today_screen.dart' show kDayCardTag;

/// Pushes check-in: content rises 24 dp and fades in on the check-in spring,
/// and slides back down as "Build my day" morphs into the hero card.
class CheckInRoute extends PageRoute<void> {
  CheckInRoute();

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Motion.checkInDuration;

  @override
  Simulation? createSimulation({required bool forward}) => SpringSimulation(
    Springs.checkIn,
    controller?.value ?? (forward ? 0 : 1),
    forward ? 1 : 0,
    0,
    snapToEnd: true,
  );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
  ) => const CheckInScreen();

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        // Fades over roughly the first 200 ms of the spring.
        final opacity = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
        );
      },
    );
  }
}

/// Morning check-in: wake time, day types, errands, "Build my day".
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  late ClockTime _wake;
  final Set<String> _types = {};
  final List<Errand> _errands = [];

  @override
  void initState() {
    super.initState();
    final now = AppScope.read(context).now;
    _wake = ClockTime(now.hour, now.minute - now.minute % kPickerMinuteStep);
  }

  DateTime _wakeDateTime(DateTime now) {
    var wake = DateTime(now.year, now.month, now.day, _wake.hour, _wake.minute);
    // Picking 23:50 shortly after midnight means last night.
    if (wake.isAfter(now.add(const Duration(hours: 12)))) {
      wake = wake.subtract(const Duration(days: 1));
    }
    return wake;
  }

  Future<void> _addErrand() async {
    final errand = await Navigator.of(context).push<Errand>(
      BlockSheetRoute<Errand>(
        scrim: EnsoPalette.of(context).scrim,
        builder: (_) => const _ErrandSheet(),
      ),
    );
    if (errand != null) setState(() => _errands.add(errand));
  }

  void _build() {
    final state = AppScope.read(context);
    state.buildDay(wake: _wakeDateTime(state.now), dayTypes: {..._types}, errands: [..._errands]);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = EnsoPalette.of(context);
    final schedule = state.schedule!;
    final now = state.now;
    final wake = _wakeDateTime(now);
    final day = AppState.appDay(wake);
    final bedtime = DateTime(day.year, day.month, day.day, 0, schedule.bedtime.dayMinutes);
    final untilBed = bedtime.difference(wake).inMinutes;
    final helper = EnsoType.caption.copyWith(
      color: p.ink2,
      fontFeatures: EnsoType.tabular,
      height: 1.2,
    );
    final label = EnsoType.label.copyWith(color: p.ink2);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateLabel(now), style: label),
                      const SizedBox(height: 4),
                      Text(
                        'You woke up at',
                        style: EnsoType.heading.copyWith(color: p.ink, height: 1.2),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, 20, Space.md, 0),
                  child: WakePicker(value: _wake, onChanged: (v) => setState(() => _wake = v)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(child: Text('Set to now, scroll to adjust', style: helper)),
                      const SizedBox(width: 12),
                      Text(
                        untilBed > 0
                            ? '${formatDuration(untilBed)} until lights out'
                            : 'Past lights out',
                        style: helper,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Text('Today is a', style: label),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      for (final t in schedule.dayTypes)
                        _Chip(
                          label: dayTypeLabel(t),
                          selected: _types.contains(t),
                          onTap: () =>
                              setState(() => _types.contains(t) ? _types.remove(t) : _types.add(t)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Text('Errands', style: label),
                ),
                Glass(
                  margin: const EdgeInsets.symmetric(horizontal: Space.md),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < _errands.length; i++)
                        _ErrandRow(
                          errand: _errands[i],
                          onRemove: () => setState(() => _errands.removeAt(i)),
                        ),
                      Pressable(
                        onTap: _addErrand,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              LineIcon(LineIcons.plus, size: 20, color: p.ink2),
                              const SizedBox(width: 12),
                              Text('Add errand', style: EnsoType.row.copyWith(color: p.ink2)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(Space.md, 32, Space.md, Space.bottomInset(context)),
                child: MorphHero(
                  tag: kDayCardTag,
                  color: p.accent,
                  radius: 30,
                  showContentInFlight: true,
                  child: PrimaryButton(label: 'Build my day', onTap: _build),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final text = EnsoType.buttonSmall.copyWith(color: selected ? p.accentInk : p.ink);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) ...[
          LineIcon(LineIcons.check, size: 18, color: p.accentInk),
          const SizedBox(width: 8),
        ],
        Text(label, style: text),
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: selected
            ? Container(
                height: 48,
                padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: content,
              )
            : Glass(
                tone: GlassTone.sunk,
                radius: 24,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: content,
                ),
              ),
      ),
    );
  }
}

class _ErrandRow extends StatelessWidget {
  const _ErrandRow({required this.errand, required this.onRemove});

  final Errand errand;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(errand.name, style: EnsoType.row.copyWith(color: p.ink)),
            ),
            const SizedBox(width: 12),
            Text(
              formatDuration(errand.minutes),
              style: EnsoType.bodySmall.copyWith(
                color: p.ink2,
                fontFeatures: EnsoType.tabular,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 12),
            IconAction(
              icon: LineIcons.close,
              label: 'Remove ${errand.name}',
              size: 18,
              box: 44,
              color: p.ink3,
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Name and length for a one-off errand. Not in the mockups, so it follows
/// the block sheet's look.
class _ErrandSheet extends StatefulWidget {
  const _ErrandSheet();

  @override
  State<_ErrandSheet> createState() => _ErrandSheetState();
}

class _ErrandSheetState extends State<_ErrandSheet> {
  static const _lengths = [15, 30, 45, 60, 90, 120];
  final _name = TextEditingController();
  int _minutes = 60;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(Errand(name, _minutes));
  }

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Glass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        shadows: Elevation.sheet(p),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          keyboard > 0 ? 24 : Space.bottomInset(context) - 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 24),
            Text('Add errand', style: EnsoType.heading.copyWith(color: p.ink)),
            const SizedBox(height: 24),
            Glass(
              tone: GlassTone.sunk,
              radius: Radii.small,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                onChanged: (_) => setState(() {}),
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                style: EnsoType.row.copyWith(color: p.ink),
                cursorColor: p.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Haircut',
                  hintStyle: EnsoType.row.copyWith(color: p.ink3),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('How long', style: EnsoType.label.copyWith(color: p.ink2)),
            const SizedBox(height: 12),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final m in _lengths)
                  _Chip(
                    label: formatDuration(m),
                    selected: m == _minutes,
                    onTap: () => setState(() => _minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            PrimaryButton(label: 'Add', onTap: _name.text.trim().isEmpty ? null : _add),
          ],
        ),
      ),
    );
  }
}
