import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../engine/models.dart';
import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ambience.dart';
import '../widgets/hero_text.dart';
import '../widgets/line_icon.dart';
import '../widgets/surfaces.dart';

/// Opens the block sheet for [blockId]. [heroTag] is the tag of the name
/// that was tapped, so it grows into the sheet title.
Future<void> showBlockSheet(
  BuildContext context, {
  required String blockId,
  required String heroTag,
}) {
  return Navigator.of(context).push(
    BlockSheetRoute<void>(
      scrim: EnsoPalette.of(context).scrim,
      builder: (_) => BlockSheet(blockId: blockId, heroTag: heroTag),
    ),
  );
}

/// A see-through page route that springs a sheet up from the bottom over a
/// scrim. Drag down to reverse; a fast release dismisses, carrying its speed.
class BlockSheetRoute<T> extends PageRoute<T> {
  BlockSheetRoute({required this.builder, required this.scrim});

  final WidgetBuilder builder;
  final Color scrim;

  /// Velocity (in route units per second, downward positive) of the drag
  /// that dismissed the sheet, so the closing spring continues it.
  double _releaseVelocity = 0;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => 'Close';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Motion.sheetDuration;

  @override
  Simulation? createSimulation({required bool forward}) {
    final from = controller?.value ?? (forward ? 0 : 1);
    final v = forward ? 0.0 : -_releaseVelocity;
    _releaseVelocity = 0;
    return SpringSimulation(Springs.sheet, from, forward ? 1 : 0, v, snapToEnd: true);
  }

  /// Follows a finger: [delta] is the fraction of the sheet height dragged.
  void dragBy(double delta) {
    final c = controller;
    if (c == null) return;
    c.value = (c.value - delta).clamp(0.0, 1.0);
  }

  /// Ends a drag. Dismisses on a fast flick down or when mostly closed.
  void release(BuildContext context, double velocity) {
    final c = controller;
    if (c == null) return;
    if (velocity > 1.2 || c.value < 0.6) {
      _releaseVelocity = velocity;
      Navigator.of(context).pop();
    } else {
      c.animateWith(SpringSimulation(Springs.sheet, c.value, 1, -velocity, snapToEnd: true));
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: FadeTransition(
              opacity: animation.drive(Tween(begin: 0.0, end: 1.0)),
              child: ColoredBox(color: scrim),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) =>
                FractionalTranslation(translation: Offset(0, 1 - animation.value), child: child),
          ),
        ),
      ],
    );
  }
}

/// Details and actions for one block. The day re-plans live behind it.
class BlockSheet extends StatelessWidget {
  const BlockSheet({super.key, required this.blockId, required this.heroTag});

  final String blockId;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = EnsoPalette.of(context);
    final plan = state.plan;
    final block = plan?.blockById(blockId);
    if (plan == null || block == null) return const SizedBox.shrink();

    final now = state.now;
    final isCurrent = !now.isBefore(block.start) && now.isBefore(block.end);
    final isPast = !block.end.isAfter(now);
    final isNext =
        state.upNext?.id == blockId || (state.current == null && state.focus?.id == blockId);
    final def = block.block;
    final category = categoryLabel(def.category);
    final overline = isCurrent
        ? 'Now · $category'
        : isPast
        ? 'Earlier · $category'
        : isNext
        ? 'Up next · $category'
        : 'Later · $category';

    final previous = _before(plan, block);
    final preview = isCurrent
        ? state.preview(const ExtendAction(15), blockId)
        : (!isPast ? state.preview(SkipAction(blockId), blockId) : null);

    final route = ModalRoute.of(context);
    final animation = route?.animation ?? const AlwaysStoppedAnimation(1.0);
    final details = CurvedAnimation(parent: animation, curve: const Interval(0.7, 1));

    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (route is BlockSheetRoute) route.dragBy(d.primaryDelta! / context.size!.height);
      },
      onVerticalDragEnd: (d) {
        if (route is BlockSheetRoute) {
          route.release(context, d.primaryVelocity! / context.size!.height);
        }
      },
      child: Glass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        shadows: Elevation.sheet(p),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            40 + MediaQuery.viewPaddingOf(context).bottom * 0.5,
          ),
          child: DefaultTextStyle(
            style: EnsoType.body.copyWith(color: p.ink),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 24),
                Overline(overline, dot: isCurrent, color: isCurrent ? p.accentInk : p.ink2),
                const SizedBox(height: 8),
                HeroText(
                  tag: heroTag,
                  text: def.name,
                  style: EnsoType.sheetHero.copyWith(color: p.ink),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RollingText(
                    '${rangeLabel(block.start, block.end)} · ${formatDuration(block.minutes)}',
                    style: EnsoType.body.copyWith(color: p.ink2, height: 1.2),
                  ),
                ),
                FadeTransition(
                  opacity: details,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isCurrent) ...[
                        const SizedBox(height: 24),
                        _Progress(block: block, now: now),
                      ],
                      const SizedBox(height: 24),
                      _DetailGroup(
                        color: p.tint(def.category),
                        rows: [
                          if (def.detail != null) ('Today', def.detail!),
                          _shrinkRow(def),
                          if (previous != null) ('Comes after', previous.block.name),
                        ],
                      ),
                      if (preview != null) ...[const SizedBox(height: 24), _PreviewLine(preview)],
                      if (!isPast) ...[
                        const SizedBox(height: 24),
                        _Actions(blockId: blockId, isCurrent: isCurrent),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (String, String) _shrinkRow(BlockDef def) {
    if (def.at != null) return ('Starts at', '${def.at} · fixed');
    final min = def.min;
    if (min == null) return ('Can shrink to', 'Fixed');
    if (min == 0) return ('Can shrink to', 'Left out if needed');
    return ('Can shrink to', formatDuration(min));
  }

  static PlannedBlock? _before(Plan plan, PlannedBlock b) {
    PlannedBlock? prev;
    for (final x in plan.blocks) {
      if (x.id == b.id) return prev;
      prev = x;
    }
    return null;
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.block, required this.now});

  final PlannedBlock block;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final total = block.end.difference(block.start).inSeconds;
    final done = now.difference(block.start).inSeconds.clamp(0, total);
    final fraction = total == 0 ? 0.0 : done / total;
    final style = EnsoType.caption.copyWith(
      color: p.ink2,
      fontFeatures: EnsoType.tabular,
      height: 1.2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          tone: GlassTone.sunk,
          radius: 3,
          child: SizedBox(
            height: 6,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction),
                duration: Motion.replanDuration,
                curve: Motion.replan,
                builder: (context, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${formatDuration(done ~/ 60)} in', style: style),
            Text('${formatDuration(minutesBetween(now, block.end))} left', style: style),
          ],
        ),
      ],
    );
  }
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.color, required this.rows});

  final Color color;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.small)),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: EnsoType.bodySmall.copyWith(color: p.ink2, height: 1.3)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: EnsoType.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                        height: 1.3,
                        fontFeatures: EnsoType.tabular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: LineIcon(LineIcons.clock, size: 18, color: p.ink2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.replanDuration,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
            child: Text(
              text,
              key: ValueKey(text),
              style: EnsoType.bodySmall.copyWith(fontSize: 14, height: 1.45, color: p.ink2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.blockId, required this.isCurrent});

  final String blockId;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    void skip() {
      Navigator.of(context).pop();
      state.act(SkipAction(blockId));
    }

    if (!isCurrent) {
      return SecondaryButton(label: 'Skip', onTap: skip);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: '+15 min',
                onTap: () => state.act(const ExtendAction(15)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(label: 'Skip', onTap: skip),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Done',
          onTap: () {
            Navigator.of(context).pop();
            state.act(DoneAction(blockId));
          },
        ),
      ],
    );
  }
}
