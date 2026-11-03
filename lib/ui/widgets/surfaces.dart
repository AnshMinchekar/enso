import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'line_icon.dart';
import 'screen_image.dart';

/// Which glass fill a [Glass] panel uses.
enum GlassTone { surface, sunk }

/// A frosted panel: blurred background plus a translucent fill. Falls back
/// to the solid colour when glass is off. Never used for primary buttons or
/// the "now" highlight.
///
/// Panels on the background draw a pre-blurred copy of the artwork aligned to
/// the screen ([Backdrops.glass]), which costs one image draw instead of a
/// live blur every frame. Sheets set [live]: they sit over moving content, so
/// they blur what is really behind them. A panel inside another panel or
/// sheet only adds its fill, like frosted glass on frosted glass.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.tone = GlassTone.surface,
    this.radius = Radii.card,
    this.borderRadius,
    this.padding,
    this.margin,
    this.shadow = false,
    this.shadows,
    this.color,
    this.live = false,
  });

  /// Blur whatever is behind the panel (sheets).
  final bool live;

  final Widget child;
  final GlassTone tone;
  final double radius;

  /// Overrides [radius], for sheets with only the top corners rounded.
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Card elevation (hero card only).
  final bool shadow;

  /// Custom shadows, for example the sheet's upward shadow.
  final List<BoxShadow>? shadows;

  /// Overrides the fill, for example a category tint.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final r = borderRadius ?? BorderRadius.circular(radius);
    final fill = color ?? (tone == GlassTone.surface ? p.surface : p.sunk);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: r),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (p.glass && !_InsideGlass.of(context)) {
      final scope = AmbienceScope.maybeOf(context);
      if (live || scope == null || scope.night) {
        body = ClipRRect(
          borderRadius: r,
          child: BackdropFilter.grouped(
            filter: glassFilter(),
            child: _InsideGlass(child: body),
          ),
        );
      } else {
        body = ScreenImage(
          asset: Backdrops.glass(scope.ambience),
          borderRadius: r,
          child: _InsideGlass(child: body),
        );
      }
    }
    final cast = shadows ?? (shadow ? Elevation.card(p) : null);
    if (cast != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(borderRadius: r, boxShadow: cast),
        child: body,
      );
    }
    return margin == null ? body : Padding(padding: margin!, child: body);
  }
}

/// Marks content that already sits on glass.
class _InsideGlass extends InheritedWidget {
  const _InsideGlass({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_InsideGlass>() != null;

  @override
  bool updateShouldNotify(_InsideGlass old) => false;
}

/// Shrinks very slightly while pressed, on the re-plan spring.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Light tick on tap.
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: Motion.replanDuration,
        curve: Motion.replan,
        child: widget.child,
      ),
    );
  }
}

/// The one primary action on a screen. 60 high, pill, accent.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onTap, this.soft = false, this.icon});

  final String label;
  final VoidCallback? onTap;

  /// Softened confirmation state ("Copied"): accentSoft fill, accentInk text.
  final bool soft;
  final LineIcons? icon;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final fg = soft ? p.accentInk : p.onAccent;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.5 : 1,
          duration: Motion.replanDuration,
          child: AnimatedContainer(
            duration: Motion.replanDuration,
            curve: Motion.replan,
            height: 60,
            decoration: BoxDecoration(
              color: soft ? p.accentSoft : p.accent,
              borderRadius: BorderRadius.circular(30),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  LineIcon(icon!, size: 20, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(label, style: EnsoType.button.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action. 56 high, pill, glass sunk.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onTap, this.fontSize = 16});

  final String label;
  final VoidCallback? onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Glass(
          tone: GlassTone.sunk,
          radius: 28,
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                label,
                style: EnsoType.buttonSmall.copyWith(
                  fontSize: fontSize,
                  color: p.ink,
                  fontFeatures: EnsoType.tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet text action, for example "Running late?" or "Turn on".
class TextAction extends StatelessWidget {
  const TextAction({super.key, required this.label, this.onTap, this.icon, this.accent = false});

  final String label;
  final VoidCallback? onTap;
  final LineIcons? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    final color = accent ? p.accentInk : p.ink2;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                LineIcon(icon!, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: EnsoType.label.copyWith(
                  fontSize: 14,
                  fontWeight: accent ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 48 × 48 icon button.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.onLongPress,
    this.size = 22,
    this.color,
    this.box = 48,
  });

  final LineIcons icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;
  final Color? color;
  final double box;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox.square(
          dimension: box,
          child: Center(
            child: LineIcon(icon, size: size, color: color ?? p.ink2),
          ),
        ),
      ),
    );
  }
}

/// Small coloured dot for a category or "now".
class Dot extends StatelessWidget {
  const Dot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Motion.replanDuration,
    curve: Motion.replan,
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// "NOW · FOCUS" style overline with the accent dot.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.dot = true, this.color});

  final String text;
  final bool dot;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
        ],
        Text(text.toUpperCase(), style: EnsoType.overline.copyWith(color: color ?? p.accentInk)),
      ],
    );
  }
}

/// Handle at the top of a sheet: 36 × 4, ink3 at 50 %.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: p.ink3.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
