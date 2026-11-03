import 'package:flutter/material.dart';

import '../../engine/models.dart';
import '../schedule_summary.dart';
import '../theme.dart';
import 'line_icon.dart';
import 'surfaces.dart';

/// 64-high bar with a back button and a title.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconAction(
              icon: LineIcons.back,
              label: 'Back',
              size: 24,
              color: p.ink,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(title, style: EnsoType.title.copyWith(color: p.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small section label above a group ("Blocks", "Day").
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.top = 12});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(8, top, 8, 0),
    child: Text(text, style: EnsoType.label.copyWith(color: EnsoPalette.of(context).ink2)),
  );
}

/// A glass group of rows.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children, this.vertical = 4});

  final List<Widget> children;
  final double vertical;

  @override
  Widget build(BuildContext context) => Glass(
    padding: EdgeInsets.symmetric(vertical: vertical),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

/// "Bedtime ........ 22:30 ›".
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.label,
    this.value,
    this.subtitle,
    this.icon,
    this.onTap,
    this.minHeight = 60,
  });

  final String label;
  final String? value;
  final String? subtitle;
  final LineIcons? icon;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Semantics(
      button: onTap != null,
      label: [label, ?value, ?subtitle].join(', '),
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  LineIcon(icon!, size: 22, color: p.ink2),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: EnsoType.body.copyWith(color: p.ink, height: 1.3)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: EnsoType.caption.copyWith(color: p.ink2, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: EnsoType.body.copyWith(
                      color: p.ink2,
                      height: 1.3,
                      fontFeatures: EnsoType.tabular,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: onTap == null
                      ? null
                      : Center(child: LineIcon(LineIcons.chevron, size: 18, color: p.ink3)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// File or clipboard card: icon well, title, one line underneath.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.icon, required this.title, required this.subtitle});

  final LineIcons icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Glass(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Glass(
            tone: GlassTone.sunk,
            radius: 16,
            child: SizedBox.square(
              dimension: 48,
              child: Center(child: LineIcon(icon, color: p.ink)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: EnsoType.bodyStrong.copyWith(color: p.ink, height: 1.3)),
                const SizedBox(height: 2),
                Text(subtitle, style: EnsoType.caption.copyWith(color: p.ink2, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A friendly, specific error with its line number. Warm food tint, never red.
class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.error, this.overlinePrefix, this.note});

  final ScheduleError error;

  /// For example "New version" → "NEW VERSION · LINE 42".
  final String? overlinePrefix;

  /// Added after the suggestion, for example that the previous schedule
  /// keeps running.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final overline = overlinePrefix == null
        ? 'Line ${error.line}'
        : '$overlinePrefix · line ${error.line}';
    final hint = [?suggestionLine(error), ?note].join(' ');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.tint(Category.food),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline.toUpperCase(),
            style: EnsoType.overline.copyWith(
              color: p.ink2,
              letterSpacing: 0.08 * 12,
              fontFeatures: EnsoType.tabular,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.message,
            style: EnsoType.body.copyWith(fontWeight: FontWeight.w500, height: 1.45, color: p.ink),
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(hint, style: EnsoType.bodySmall.copyWith(fontSize: 14, color: p.ink2)),
          ],
        ],
      ),
    );
  }
}

/// "Blocks" and "Rules" for a schedule, as on the schedule file screen.
class BlocksAndRules extends StatelessWidget {
  const BlocksAndRules({super.key, required this.schedule});

  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final lengthStyle = EnsoType.caption.copyWith(
      color: p.ink2,
      height: 1.3,
      fontFeatures: EnsoType.tabular,
    );
    Widget row(String name, String length, Color dot) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Dot(color: dot),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: EnsoType.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: p.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(length, style: lengthStyle),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLabel('Blocks'),
        const SizedBox(height: 12),
        RowGroup(
          children: [
            for (final b in schedule.blocks) row(b.name, blockLengthLabel(b), p.dot(b.category)),
            row('Lights out', '${schedule.bedtime} · fixed', p.dot(Category.rest)),
          ],
        ),
        const SizedBox(height: 12),
        const GroupLabel('Rules'),
        const SizedBox(height: 12),
        RowGroup(
          vertical: 8,
          children: [
            for (final r in scheduleRules(schedule))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(r, style: EnsoType.bodySmall.copyWith(height: 1.45, color: p.ink)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Fades a scrolling area out at the bottom, as in the mockups.
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, required this.child, this.from = 0.8});

  final Widget child;
  final double from;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Colors.black, Colors.black, Colors.transparent],
      stops: [0, from, 1],
    ).createShader(rect),
    child: child,
  );
}

/// Picks one option in a sheet, for example the heads-up length.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.replanDuration,
          curve: Motion.replan,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            boxShadow: [
              BoxShadow(
                color: selected ? p.accent : p.accent.withValues(alpha: 0),
                spreadRadius: 1.5,
              ),
            ],
          ),
          child: Glass(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: EnsoType.bodyStrong.copyWith(color: p.ink, height: 1.3)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: EnsoType.bodySmall.copyWith(
                            fontSize: 14,
                            height: 1.4,
                            color: p.ink2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return AnimatedContainer(
      duration: Motion.replanDuration,
      curve: Motion.replan,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? p.accent : p.ink3, width: 1.5),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: Motion.replanDuration,
        curve: Motion.replan,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
