import 'package:flutter/material.dart';

/// Shared bounds between a button and a card: during the flight the shape
/// blends colour and corner radius, and the button's label fades out early.
/// Used for "Check in" → "Build my day" → hero card.
class MorphHero extends StatelessWidget {
  const MorphHero({
    super.key,
    required this.tag,
    required this.color,
    required this.radius,
    required this.child,
    this.showContentInFlight = false,
  });

  final String tag;

  /// Fill used while flying.
  final Color color;

  /// Corner radius used while flying.
  final double radius;
  final Widget child;

  /// Buttons show their label while it fades; cards stay blank until landing.
  final bool showContentInFlight;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
        final from = (fromContext.widget as Hero).child as _MorphBody;
        final to = (toContext.widget as Hero).child as _MorphBody;
        final below = direction == HeroFlightDirection.push ? from : to;
        final above = direction == HeroFlightDirection.push ? to : from;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            // The label belongs to whichever end is a button; it is only
            // visible near that end.
            final aboveLabel = above.showContentInFlight ? ((t - 0.7) / 0.3).clamp(0.0, 1.0) : 0.0;
            final belowLabel = below.showContentInFlight ? ((0.3 - t) / 0.3).clamp(0.0, 1.0) : 0.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(below.radius + (above.radius - below.radius) * t),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Color.lerp(below.color, above.color, t)!),
                  if (belowLabel > 0) Opacity(opacity: belowLabel, child: below.child),
                  if (aboveLabel > 0) Opacity(opacity: aboveLabel, child: above.child),
                ],
              ),
            );
          },
        );
      },
      child: _MorphBody(
        color: color,
        radius: radius,
        showContentInFlight: showContentInFlight,
        child: child,
      ),
    );
  }
}

class _MorphBody extends StatelessWidget {
  const _MorphBody({
    required this.color,
    required this.radius,
    required this.showContentInFlight,
    required this.child,
  });

  final Color color;
  final double radius;
  final bool showContentInFlight;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
