import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'routes.dart';
import 'screens/today_screen.dart';
import 'theme.dart';
import 'widgets/ambience.dart';
import 'widgets/screen_image.dart';

/// Root: ambience background behind every screen, theme that follows the time
/// of day and cross-fades over ~2 s.
class EnsoApp extends StatelessWidget {
  const EnsoApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: _Shell(state: state),
  );
}

/// Rebuilds the app frame only when the look changes (time of day, wind
/// down), not on every tap: screens listen to [AppScope] themselves.
class _Shell extends StatefulWidget {
  const _Shell({required this.state});

  final AppState state;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  static final Map<Ambience, ThemeData> _themes = {};

  late Ambience _ambience = widget.state.ambience;
  late bool _night = widget.state.isWindDown;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
  }

  @override
  void didUpdateWidget(_Shell old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_onState);
      widget.state.addListener(_onState);
      _onState();
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    final a = widget.state.ambience;
    final n = widget.state.isWindDown;
    if (a != _ambience || n != _night) {
      setState(() {
        _ambience = a;
        _night = n;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Decode every background up front so a change of look never flashes.
    for (final a in Ambience.values) {
      precacheImage(AssetImage(Backdrops.asset(a)), context);
      precacheImage(AssetImage(Backdrops.glass(a)), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themes.putIfAbsent(_ambience, () => buildTheme(_ambience));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle(_ambience.brightness),
      child: MaterialApp(
        title: 'Enso',
        debugShowCheckedModeBanner: false,
        theme: theme,
        themeAnimationDuration: Springs.ambience,
        themeAnimationCurve: Curves.easeInOut,
        builder: (context, child) => AmbienceScope(
          ambience: _ambience,
          night: _night,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: AmbienceBackground(ambience: _ambience, night: _night),
              ),
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
        ),
        onGenerateRoute: (settings) => _HomeRoute(settings: settings),
      ),
    );
  }
}

/// Today. Fades out underneath while another screen is in front.
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
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => nextRoute is EnsoPageRoute;

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
