import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/check_in_screen.dart';
import 'screens/today_screen.dart';
import 'theme.dart';
import 'widgets/ambience.dart';

/// Root: ambience background behind every screen, theme that follows the time
/// of day and cross-fades over ~2 s.
class EnsoApp extends StatelessWidget {
  const EnsoApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(
        builder: (context) {
          final s = AppScope.of(context);
          final ambience = s.ambience;
          final theme = buildTheme(ambience);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle(ambience.brightness),
            child: MaterialApp(
              title: 'Enso',
              debugShowCheckedModeBanner: false,
              theme: theme,
              themeAnimationDuration: Springs.ambience,
              themeAnimationCurve: Curves.easeInOut,
              builder: (context, child) => Stack(
                fit: StackFit.expand,
                children: [
                  AmbienceBackground(ambience: ambience, night: s.isWindDown),
                  // No Scaffold: a transparent Material lets text fields work
                  // while the ambience shows through.
                  Material(
                    type: MaterialType.transparency,
                    child: BackdropGroup(
                      child: DefaultTextStyle(
                        style: EnsoType.body.copyWith(color: EnsoPalette.of(context).ink),
                        child: child!,
                      ),
                    ),
                  ),
                ],
              ),
              onGenerateRoute: (settings) => _HomeRoute(settings: settings),
            ),
          );
        },
      ),
    );
  }
}

/// Today. Fades out underneath while check-in is in front.
class _HomeRoute extends PageRoute<void> {
  _HomeRoute({super.settings});

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => nextRoute is CheckInRoute;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
  ) => const TodayScreen();

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: secondaryAnimation.drive(Tween(begin: 1.0, end: 0.0)), child: child);
}
