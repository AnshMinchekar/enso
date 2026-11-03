import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'theme.dart';

/// The app's page transition: the new screen rises 24 dp and fades in on the
/// check-in spring; the screen below fades out underneath. Nothing pops in.
class EnsoPageRoute<T> extends PageRoute<T> {
  EnsoPageRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

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
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => nextRoute is EnsoPageRoute;

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
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        // Fades over roughly the first 200 ms of the spring.
        final opacity = ((t - 0.45) / 0.55).clamp(0.0, 1.0) * (1 - secondaryAnimation.value);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
        );
      },
    );
  }
}

/// Pushes [screen] with the app's transition.
Future<T?> pushScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(EnsoPageRoute<T>(builder: (_) => screen));
