import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-screen artwork for the time of day. Changes cross-fade over ~2 s.
class AmbienceBackground extends StatelessWidget {
  const AmbienceBackground({super.key, required this.ambience, this.night = false});

  final Ambience ambience;

  /// Wind down: the solid night colour instead of artwork.
  final bool night;

  @override
  Widget build(BuildContext context) {
    final key = night ? 'night-${ambience.brightness.name}' : ambience.name;
    return AnimatedSwitcher(
      duration: Springs.ambience,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(
        key: ValueKey(key),
        child: night ? _Night(ambience: ambience) : _Artwork(ambience: ambience),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.ambience});

  final Ambience ambience;

  @override
  Widget build(BuildContext context) {
    final wash = Backdrops.wash(ambience);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Backdrops.base(ambience)),
        Image.asset(
          Backdrops.asset(ambience),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
        if (wash != null) ColoredBox(color: wash),
      ],
    );
  }
}

class _Night extends StatelessWidget {
  const _Night({required this.ambience});

  final Ambience ambience;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: EnsoPalette.forBrightness(ambience.brightness).night);
}

/// The slow progress ring on the hero card: 96 px, radius 42, stroke 4,
/// sunk track, accent progress from 12 o'clock.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, required this.child, this.size = 96});

  /// 0 to 1.
  final double progress;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0, 1)),
        duration: Motion.replanDuration,
        curve: Motion.replan,
        builder: (context, value, child) =>
            CustomPaint(painter: _RingPainter(value, p.sunk, p.accent), child: child),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.track, this.color);

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 96;
    final center = size.center(Offset.zero);
    final radius = 42 * scale;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..color = track;
    canvas.drawCircle(center, radius, paint);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}

/// Text whose characters cross-fade one by one when they change, so a time
/// like 12:30 → 12:45 only fades the digits that moved. Tabular figures keep
/// the column still.
class RollingText extends StatelessWidget {
  const RollingText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final s = style.copyWith(fontFeatures: EnsoType.tabular);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < text.length; i++)
          AnimatedSwitcher(
            duration: Motion.replanDuration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.center, children: [...previous, ?current]),
            child: Text(text[i], key: ValueKey('$i${text[i]}'), style: s),
          ),
      ],
    );
  }
}
