import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/models.dart';
import '../format.dart';
import '../theme.dart';
import 'ambience.dart';
import 'hero_text.dart';
import 'surfaces.dart';

/// Height of one timeline row: padding 12 + name + detail + padding 12.
const double kTimelineRowHeight = 66;

/// Id of the closing "Lights out" row.
const String kBedtimeRowId = '__bedtime';

/// Hero tag for a timeline row's name.
String rowHeroTag(String blockId) => 'row-$blockId';

class _RowData {
  _RowData({
    required this.id,
    required this.time,
    required this.name,
    required this.detail,
    required this.category,
    this.block,
  });

  final String id;
  final DateTime time;
  final String name;
  final String detail;
  final Category? category;
  final PlannedBlock? block;

  static List<_RowData> fromPlan(Plan plan) => [
    for (final b in plan.blocks)
      _RowData(
        id: b.id,
        time: b.start,
        name: b.block.name,
        detail: _detail(plan, b),
        category: b.block.category,
        block: b,
      ),
    _RowData(
      id: kBedtimeRowId,
      time: plan.bedtime,
      name: 'Lights out',
      detail: 'Bedtime',
      category: Category.rest,
    ),
  ];

  static String _detail(Plan plan, PlannedBlock b) {
    final length = formatDuration(b.minutes);
    final cut = plan.cutFor(b.id);
    if (cut != null && !cut.dropped && b.minutes < cut.fromMinutes) {
      return '$length · usually ${formatDuration(cut.fromMinutes)}';
    }
    if (b.block.category == Category.errand) return 'Errand · $length';
    final d = b.block.detail;
    return d == null ? length : '$d · $length';
  }
}

/// The vertical flow of the day. Past rows fade, the current one is accented,
/// future ones are quiet. Opens scrolled to now.
class Timeline extends StatefulWidget {
  const Timeline({
    super.key,
    required this.plan,
    required this.now,
    required this.onTap,
    this.stagger = false,
    this.fadeFrom = 0.65,
  });

  final Plan plan;
  final DateTime now;
  final void Function(PlannedBlock block, String heroTag) onTap;

  /// Rows rise in one after another (after check-in).
  final bool stagger;

  /// Where the bottom fade starts, as a fraction of the height.
  final double fadeFrom;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  final _listKey = GlobalKey<AnimatedListState>();
  final _scroll = ScrollController();
  late List<_RowData> _rows = _RowData.fromPlan(widget.plan);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow(animate: widget.stagger));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToNow({required bool animate}) {
    if (!_scroll.hasClients) return;
    var index = _rows.indexWhere((r) => r.block != null && r.block!.end.isAfter(widget.now));
    if (index < 0) index = _rows.length - 1;
    final target = ((index - 1) * kTimelineRowHeight).clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: Motion.checkInDuration * 2, curve: Motion.checkIn);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(Timeline old) {
    super.didUpdateWidget(old);
    if (identical(old.plan, widget.plan)) return;
    final next = _RowData.fromPlan(widget.plan);
    final nextIds = {for (final r in next) r.id};
    final oldIds = {for (final r in _rows) r.id};
    final list = _listKey.currentState;
    if (list != null) {
      for (var i = _rows.length - 1; i >= 0; i--) {
        final gone = _rows[i];
        if (nextIds.contains(gone.id)) continue;
        list.removeItem(
          i,
          (context, animation) => _collapse(animation, _row(gone, heroEnabled: false)),
          duration: Motion.replanDuration,
        );
      }
      for (var i = 0; i < next.length; i++) {
        if (!oldIds.contains(next[i].id)) list.insertItem(i, duration: Motion.replanDuration);
      }
    }
    _rows = next;
  }

  Widget _collapse(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Motion.replan);
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: curved, child: child),
    );
  }

  Widget _row(_RowData r, {bool heroEnabled = true}) {
    final b = r.block;
    final now = widget.now;
    final isNow = b != null && !now.isBefore(b.start) && now.isBefore(b.end);
    final isPast = b != null && !b.end.isAfter(now);
    return _TimelineRow(
      data: r,
      isNow: isNow,
      isPast: isPast,
      heroEnabled: heroEnabled,
      onTap: b == null ? null : () => widget.onTap(b, rowHeroTag(b.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: [0, widget.fadeFrom, 1],
      ).createShader(rect),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        child: Stack(
          children: [
            // Rail through the dots: 12 padding + 52 time + 12 gap + 10.
            Positioned(left: 85.5, top: 0, bottom: 0, width: 1, child: ColoredBox(color: p.line)),
            AnimatedList(
              key: _listKey,
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 160),
              initialItemCount: _rows.length,
              itemBuilder: (context, index, animation) {
                final row = _row(_rows[index]);
                final entering = animation.status != AnimationStatus.completed;
                if (entering) return _collapse(animation, row);
                if (widget.stagger) {
                  return _StaggerIn(
                    delay: Duration(milliseconds: 30 * index.clamp(0, 14)),
                    child: row,
                  );
                }
                return row;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.data,
    required this.isNow,
    required this.isPast,
    required this.heroEnabled,
    this.onTap,
  });

  final _RowData data;
  final bool isNow;
  final bool isPast;
  final bool heroEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final nameStyle = EnsoType.row.copyWith(
      color: p.ink,
      fontWeight: isNow ? FontWeight.w600 : FontWeight.w500,
      height: 1.35,
    );
    return Semantics(
      button: onTap != null,
      label: '${formatClock(data.time)}, ${data.name}, ${data.detail}${isNow ? ', now' : ''}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: false,
        child: AnimatedOpacity(
          opacity: isPast ? 0.42 : 1,
          duration: Motion.replanDuration,
          curve: Motion.replan,
          child: AnimatedContainer(
            duration: Motion.replanDuration,
            curve: Motion.replan,
            height: kTimelineRowHeight,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNow ? p.accentSoft : p.accentSoft.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(Radii.row),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: RollingText(
                    formatClock(data.time),
                    style: EnsoType.time.copyWith(color: p.ink2),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 20,
                  child: Center(
                    child: Dot(
                      color: isNow ? p.accent : p.dot(data.category),
                      size: isNow ? 12 : 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeroText(
                        tag: rowHeroTag(data.id),
                        text: data.name,
                        style: nameStyle,
                        maxLines: 1,
                        enabled: heroEnabled && data.block != null,
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: Motion.replanDuration,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, ?current],
                        ),
                        child: Text(
                          data.detail,
                          key: ValueKey(data.detail),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnsoType.caption.copyWith(color: p.ink2, height: 1.3),
                        ),
                      ),
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
}

/// Rises 12 dp and fades in after [delay], on the check-in spring.
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.checkInDuration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Motion.checkIn);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _c.value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - curved.value)), child: child),
      ),
    );
  }
}
