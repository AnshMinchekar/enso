import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/models.dart';
import '../format.dart';
import '../theme.dart';
import 'ambience.dart';
import 'hero_text.dart';
import 'line_icon.dart';
import 'surfaces.dart';

/// Height of one timeline row: padding 12 + name + detail + padding 12.
const double kTimelineRowHeight = 66;

/// Id of the closing "Lights out" row.
const String kBedtimeRowId = '__bedtime';

/// Id of the "Earlier today" row that folds away finished blocks.
const String kEarlierRowId = '__earlier';

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
    this.hiddenCount = 0,
    this.expanded = false,
  });

  final String id;
  final DateTime time;
  final String name;
  final String detail;
  final Category? category;
  final PlannedBlock? block;

  /// For the "Earlier today" row.
  final int hiddenCount;
  final bool expanded;

  bool get isEarlierToggle => id == kEarlierRowId;

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

/// The vertical flow of the day, as a sliver inside Today's scroll view.
/// Past rows fade, the current one is accented, future ones are quiet. It
/// opens on the block before now; anything earlier folds behind a quiet
/// "Earlier today" row.
class TimelineSliver extends StatefulWidget {
  const TimelineSliver({
    super.key,
    required this.plan,
    required this.now,
    required this.onTap,
    this.stagger = false,
  });

  final Plan plan;
  final DateTime now;
  final void Function(PlannedBlock block, String heroTag) onTap;

  /// Rows rise in one after another (after check-in).
  final bool stagger;

  @override
  State<TimelineSliver> createState() => _TimelineSliverState();
}

class _TimelineSliverState extends State<TimelineSliver> {
  final _listKey = GlobalKey<SliverAnimatedListState>();
  bool _expanded = false;
  late List<_RowData> _entries = _compute();

  List<_RowData> _compute() {
    final rows = _RowData.fromPlan(widget.plan);
    var focus = rows.indexWhere((r) => r.block != null && r.block!.end.isAfter(widget.now));
    if (focus < 0) focus = rows.length - 1;
    final firstVisible = focus > 0 ? focus - 1 : 0;
    if (firstVisible == 0) return rows;
    return [
      _RowData(
        id: kEarlierRowId,
        time: rows.first.time,
        name: 'Earlier today',
        detail: '',
        category: null,
        hiddenCount: firstVisible,
        expanded: _expanded,
      ),
      ...(_expanded ? rows : rows.skip(firstVisible)),
    ];
  }

  /// Animates the list from the current entries to freshly computed ones:
  /// rows that left collapse, new rows grow in, the rest update in place.
  void _sync() {
    final next = _compute();
    final nextIds = {for (final r in next) r.id};
    final oldIds = {for (final r in _entries) r.id};
    final list = _listKey.currentState;
    if (list != null) {
      for (var i = _entries.length - 1; i >= 0; i--) {
        final gone = _entries[i];
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
    _entries = next;
  }

  @override
  void didUpdateWidget(TimelineSliver old) {
    super.didUpdateWidget(old);
    if (!identical(old.plan, widget.plan) || old.now != widget.now) _sync();
  }

  void _toggleEarlier() => setState(() {
    _expanded = !_expanded;
    _sync();
  });

  Widget _collapse(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Motion.replan);
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: curved, child: child),
    );
  }

  Widget _row(_RowData r, {bool heroEnabled = true}) {
    if (r.isEarlierToggle) return _EarlierRow(data: r, onTap: _toggleEarlier);
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
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: _entries.length,
      itemBuilder: (context, index, animation) {
        final row = _row(_entries[index]);
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
    );
  }
}

/// The 1 px rail through the dots: 12 padding + 52 time + 12 gap + 10.
class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) => Positioned(
    left: 85.5,
    top: 0,
    bottom: 0,
    width: 1,
    child: ColoredBox(color: EnsoPalette.of(context).line),
  );
}

/// "Earlier today · 4 blocks", folding finished blocks away.
class _EarlierRow extends StatelessWidget {
  const _EarlierRow({required this.data, required this.onTap});

  final _RowData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final n = data.hiddenCount;
    final label = data.expanded
        ? 'Hide earlier blocks'
        : 'Earlier today · $n ${n == 1 ? 'block' : 'blocks'}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Stack(
            children: [
              const _Rail(),
              Padding(
                padding: const EdgeInsets.only(left: 12 + 52 + 12 + 20 + 12),
                child: Row(
                  children: [
                    Text(label, style: EnsoType.label.copyWith(color: p.ink2)),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: data.expanded ? -0.25 : 0.25,
                      duration: Motion.replanDuration,
                      curve: Motion.replan,
                      child: LineIcon(LineIcons.chevron, size: 16, color: p.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        child: Stack(
          children: [
            const _Rail(),
            AnimatedOpacity(
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
          ],
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
