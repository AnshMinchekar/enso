/// Every design token for Enso. Source: `docs/design/style-sheet.md`.
///
/// The mockups render glass surfaces over time-of-day backgrounds; those
/// resolved values are the defaults here. The solid values are kept for the
/// fallback when blur is switched off ([kGlassSurfaces]).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../engine/models.dart';

/// Glass surfaces (translucent fill + backdrop blur) as in the mockups. Set to
/// false to use the solid fallback colours everywhere.
const bool kGlassSurfaces = true;

// -----------------------------------------------------------------------------
// Ambience

/// The look by time of day. There is no theme setting.
enum Ambience {
  /// 04:00–11:59, light tokens, cool sky.
  morning,

  /// 12:00–17:59, light tokens, warm cozy background.
  afternoon,

  /// 18:00–03:59, dark tokens, night gradient with stars.
  evening;

  Brightness get brightness => this == evening ? Brightness.dark : Brightness.light;

  /// "Good morning." and so on.
  String get greeting => switch (this) {
    morning => 'Good morning.',
    afternoon => 'Good afternoon.',
    evening => 'Good evening.',
  };

  static Ambience at(DateTime t) {
    final h = t.hour;
    if (h >= 4 && h < 12) return morning;
    if (h >= 12 && h < 18) return afternoon;
    return evening;
  }
}

/// Background artwork for each ambience.
class Backdrops {
  Backdrops._();

  static const String morning = 'assets/backgrounds/morning.webp';
  static const String afternoon = 'assets/backgrounds/afternoon.webp';
  static const String evening = 'assets/backgrounds/evening.webp';

  static String asset(Ambience a) => switch (a) {
    Ambience.morning => morning,
    Ambience.afternoon => afternoon,
    Ambience.evening => evening,
  };

  /// Colour painted under the image while it loads.
  static Color base(Ambience a) => switch (a) {
    Ambience.morning => const Color(0xFFBFD3EA),
    Ambience.afternoon => const Color(0xFFF7CFAE),
    Ambience.evening => const Color(0xFF0B1026),
  };

  /// Cream wash over the morning sky, rgba(245,242,236,.42).
  static Color? wash(Ambience a) => a == Ambience.morning ? const Color(0x6BF5F2EC) : null;
}

// -----------------------------------------------------------------------------
// Colours

/// Custom colour tokens, read with `EnsoPalette.of(context)`.
@immutable
class EnsoPalette extends ThemeExtension<EnsoPalette> {
  const EnsoPalette({
    required this.background,
    required this.surface,
    required this.sunk,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.shadow,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentSoft,
    required this.scrim,
    required this.night,
    required this.nightCard,
    required this.tints,
    required this.dots,
    required this.glass,
  });

  /// Screen colour when no artwork is shown.
  final Color background;

  /// Cards, sheets, the hero card.
  final Color surface;

  /// Chips, secondary buttons, icon wells, banners.
  final Color sunk;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color ink2;

  /// Icons, dividers, the sheet handle.
  final Color ink3;

  /// Timeline rail.
  final Color line;

  /// Card and sheet shadows.
  final Color shadow;

  /// "Now" and the primary action. Nothing else.
  final Color accent;

  /// Accent-coloured text ("NOW", "Turn on").
  final Color accentInk;

  /// Text on the primary button.
  final Color onAccent;

  /// Now row, selected chips.
  final Color accentSoft;

  /// Behind bottom sheets.
  final Color scrim;

  /// Wind down screen.
  final Color night;

  /// "Tomorrow" card on wind down.
  final Color nightCard;

  /// Category tint fills, indexed by [Category.index].
  final List<Color> tints;

  /// Category dots, indexed by [Category.index].
  final List<Color> dots;

  /// Whether [surface] and [sunk] are glass (blurred) or solid.
  final bool glass;

  Color tint(Category? c) => tints[(c ?? Category.rest).index];
  Color dot(Category? c) => dots[(c ?? Category.rest).index];

  static EnsoPalette of(BuildContext context) => Theme.of(context).extension<EnsoPalette>()!;

  // Category order follows Category: focus, body, food, rest, leisure, errand.
  static const List<Color> _dotsLight = [
    Color(0xFF7A89A2),
    Color(0xFFB68767),
    Color(0xFFB19A5F),
    Color(0xFF958AA3),
    Color(0xFFB37F7F),
    Color(0xFF8E887F),
  ];
  static const List<Color> _dotsDark = [
    Color(0xFF94A3BB),
    Color(0xFFC99E80),
    Color(0xFFC8B27A),
    Color(0xFFADA2BA),
    Color(0xFFC99999),
    Color(0xFF8A847B),
  ];

  /// Light tokens over the sky (morning and afternoon), glass surfaces.
  /// Tints and accentSoft are `color-mix(in oklch, colour 20 % / 24 %, surface)`
  /// from the mockup, resolved.
  static const EnsoPalette light = EnsoPalette(
    background: Color(0xFFF5F2EC),
    surface: Color(0x9EFFFFFF), // rgba(255,255,255,.62)
    sunk: Color(0x6BFFFFFF), // rgba(255,255,255,.42)
    ink: Color(0xFF2A2825),
    ink2: Color(0xFF45413B),
    ink3: Color(0xFF8E887F),
    line: Color(0xFFE2DDD4),
    shadow: Color(0x0F463728), // rgba(70,55,40,.06)
    accent: Color(0xFF5C6F8C),
    accentInk: Color(0xFF475A76),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xB5C5CCD7),
    scrim: Color(0x4D141A30), // rgba(20,26,48,.3)
    night: Color(0xFFD9DCE6),
    nightCard: Color(0xFFE6E8EF),
    tints: [
      Color(0xB1D7DCE4),
      Color(0xB1EBDCD2),
      Color(0xB1E8E1D1),
      Color(0xB1DFDCE4),
      Color(0xB1EAD9D9),
      Color(0xB1DDDBD9),
    ],
    dots: _dotsLight,
    glass: true,
  );

  /// Dark tokens over the night background, glass surfaces.
  static const EnsoPalette dark = EnsoPalette(
    background: Color(0xFF1B1A18),
    surface: Color(0x991A1C2C), // rgba(26,28,44,.6)
    sunk: Color(0x8C2C2E40), // rgba(44,46,64,.55)
    ink: Color(0xFFEEEAE3),
    ink2: Color(0xFFCFCAC1),
    ink3: Color(0xFF78726A),
    line: Color(0xFF34322E),
    shadow: Color(0x4D000000), // rgba(0,0,0,.3)
    accent: Color(0xFF9FB0CB),
    accentInk: Color(0xFFB7C5DB),
    onAccent: Color(0xFF161C26),
    accentSoft: Color(0xB1454A5E),
    scrim: Color(0x99040612), // rgba(4,6,18,.6)
    night: Color(0xFF070A1A),
    nightCard: Color(0xFF141A33),
    tints: [
      Color(0xAD3B3F53),
      Color(0xAD473D54),
      Color(0xAD4D3E57),
      Color(0xAD3F4053),
      Color(0xAD443E54),
      Color(0xAD3E3644),
    ],
    dots: _dotsDark,
    glass: true,
  );

  /// Solid fallback, light (the base values in `docs/specs.md`).
  static const EnsoPalette lightSolid = EnsoPalette(
    background: Color(0xFFF5F2EC),
    surface: Color(0xFFFCFAF6),
    sunk: Color(0xFFECE7DF),
    ink: Color(0xFF2A2825),
    ink2: Color(0xFF6B665E),
    ink3: Color(0xFF8E887F),
    line: Color(0xFFE2DDD4),
    shadow: Color(0x0F463728),
    accent: Color(0xFF5C6F8C),
    accentInk: Color(0xFF475A76),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE2E7EF),
    scrim: Color(0x521E1914), // rgba(30,25,20,.32)
    night: Color(0xFFE3DDD3),
    nightCard: Color(0xFFEDE8E0),
    tints: [
      Color(0xFFE5E9EF),
      Color(0xFFF1E5DA),
      Color(0xFFF1EBD8),
      Color(0xFFEAE6EE),
      Color(0xFFF1E3E3),
      Color(0xFFEAE7E2),
    ],
    dots: _dotsLight,
    glass: false,
  );

  /// Solid fallback, dark.
  static const EnsoPalette darkSolid = EnsoPalette(
    background: Color(0xFF1B1A18),
    surface: Color(0xFF252420),
    sunk: Color(0xFF2F2D29),
    ink: Color(0xFFEEEAE3),
    ink2: Color(0xFFA8A299),
    ink3: Color(0xFF78726A),
    line: Color(0xFF34322E),
    shadow: Color(0x4D000000),
    accent: Color(0xFF9FB0CB),
    accentInk: Color(0xFFB7C5DB),
    onAccent: Color(0xFF161C26),
    accentSoft: Color(0xFF2A303B),
    scrim: Color(0x8C000000), // rgba(0,0,0,.55)
    night: Color(0xFF121110),
    nightCard: Color(0xFF1D1C1A),
    tints: [
      Color(0xFF252A31),
      Color(0xFF342B25),
      Color(0xFF322E23),
      Color(0xFF2C2930),
      Color(0xFF342828),
      Color(0xFF2D2C29),
    ],
    dots: _dotsDark,
    glass: false,
  );

  static EnsoPalette forBrightness(Brightness b) => switch ((b, kGlassSurfaces)) {
    (Brightness.light, true) => light,
    (Brightness.dark, true) => dark,
    (Brightness.light, false) => lightSolid,
    (Brightness.dark, false) => darkSolid,
  };

  @override
  EnsoPalette copyWith() => this;

  @override
  EnsoPalette lerp(EnsoPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) c(a[i], b[i]),
    ];
    return EnsoPalette(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      sunk: c(sunk, other.sunk),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      line: c(line, other.line),
      shadow: c(shadow, other.shadow),
      accent: c(accent, other.accent),
      accentInk: c(accentInk, other.accentInk),
      onAccent: c(onAccent, other.onAccent),
      accentSoft: c(accentSoft, other.accentSoft),
      scrim: c(scrim, other.scrim),
      night: c(night, other.night),
      nightCard: c(nightCard, other.nightCard),
      tints: l(tints, other.tints),
      dots: l(dots, other.dots),
      glass: t < 0.5 ? glass : other.glass,
    );
  }
}

// -----------------------------------------------------------------------------
// Type

/// Manrope, bundled. Tabular figures on every time and duration.
class EnsoType {
  EnsoType._();

  static const String family = 'Manrope';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle _s(
    double size,
    FontWeight weight, {
    double letterEm = 0,
    double? height,
    bool tabularFigures = false,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterEm * size,
    height: height,
    fontFeatures: tabularFigures ? tabular : null,
  );

  /// 22:30 on wind down. 104 / 200.
  static final TextStyle clock = _s(
    104,
    FontWeight.w200,
    letterEm: -0.045,
    height: 1,
    tabularFigures: true,
  );

  /// Wake picker centre row. 60 / 300.
  static final TextStyle picker = _s(60, FontWeight.w300, letterEm: -0.02, tabularFigures: true);

  /// "Good morning." 48 / 300.
  static final TextStyle greeting = _s(48, FontWeight.w300, letterEm: -0.03, height: 1.08);

  /// Onboarding welcome. 42 / 300.
  static final TextStyle display = _s(42, FontWeight.w300, letterEm: -0.025, height: 1.12);

  /// Hero card block name. 36 / 300.
  static final TextStyle hero = _s(36, FontWeight.w300, letterEm: -0.025, height: 1.1);

  /// Block sheet title. 38 / 300.
  static final TextStyle sheetHero = _s(38, FontWeight.w300, letterEm: -0.025, height: 1.1);

  /// Step and sheet headings, "You woke up at". 32 / 300.
  static final TextStyle heading = _s(32, FontWeight.w300, letterEm: -0.02, height: 1.15);

  /// "When did you wake up?" 24 / 300.
  static final TextStyle subheading = _s(24, FontWeight.w300, letterEm: -0.01);

  /// Today, Schedule file. 22 / 500.
  static final TextStyle title = _s(22, FontWeight.w500, letterEm: -0.01);

  /// Ring time left. 20 / 400.
  static final TextStyle ring = _s(20, FontWeight.w400, letterEm: -0.01, tabularFigures: true);

  /// Card titles, Up next name. 17 / 500.
  static final TextStyle bodyStrong = _s(17, FontWeight.w500);

  /// Primary button. 17 / 600.
  static final TextStyle button = _s(17, FontWeight.w600);

  /// Secondary buttons, chips. 15 / 600.
  static final TextStyle buttonSmall = _s(15, FontWeight.w600);

  /// Timeline row name. 16 / 500.
  static final TextStyle row = _s(16, FontWeight.w500);

  /// Body copy. 16 / 400.
  static final TextStyle body = _s(16, FontWeight.w400, height: 1.5);

  /// Smaller body copy. 15 / 400.
  static final TextStyle bodySmall = _s(15, FontWeight.w400, height: 1.5);

  /// Times in rows and ranges. 14 / 400, tabular.
  static final TextStyle time = _s(14, FontWeight.w400, tabularFigures: true);

  /// Row details, helper lines. 13 / 400.
  static final TextStyle caption = _s(13, FontWeight.w400, height: 1.4);

  /// Section labels ("Your day", "Up next"). 13 / 600.
  static final TextStyle label = _s(13, FontWeight.w600);

  /// "NOW · FOCUS". 12 / 700, uppercase, +0.1 em.
  static final TextStyle overline = _s(12, FontWeight.w700, letterEm: 0.1);
}

// -----------------------------------------------------------------------------
// Spacing, radii, elevation

/// 8 pt grid.
class Space {
  Space._();

  /// Chip gaps, icon to label.
  static const double xs = 8;

  /// Card to card.
  static const double sm = 12;

  /// Card margin from screen edge.
  static const double md = 16;

  /// Card padding, text margin.
  static const double lg = 24;

  /// Onboarding margins.
  static const double xl = 32;

  /// Bottom inset above the gesture bar.
  static const double bottom = 48;

  /// Bottom inset for primary buttons: 48 dp, or more if the system bar is taller.
  static double bottomInset(BuildContext context) {
    final system = MediaQuery.viewPaddingOf(context).bottom;
    return system + 16 > bottom ? system + 16 : bottom;
  }
}

/// Corner radii. No borders anywhere.
class Radii {
  Radii._();

  static const double dot = 6;
  static const double row = 16;
  static const double small = 20;
  static const double card = 24;
  static const double hero = 28;
  static const double sheet = 32;
  static const double pill = 999;
}

/// Shadows. Only cards and sheets cast them.
class Elevation {
  Elevation._();

  static List<BoxShadow> card(EnsoPalette p) => [
    BoxShadow(color: p.shadow, offset: const Offset(0, 1), blurRadius: 2),
    BoxShadow(color: p.shadow, offset: const Offset(0, 12), blurRadius: 32),
  ];

  static List<BoxShadow> sheet(EnsoPalette p) => [
    BoxShadow(color: p.shadow, offset: const Offset(0, -12), blurRadius: 40),
  ];
}

/// Backdrop blur for glass: CSS `blur(24px) saturate(1.3)`. A CSS blur
/// radius of 24 is a Gaussian sigma of 12.
ui.ImageFilter glassFilter() => ui.ImageFilter.compose(
  outer: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12, tileMode: TileMode.mirror),
  inner: const ColorFilter.matrix(_saturate130),
);

// Saturation matrix for s = 1.3 (Rec. 709 luma weights, as CSS saturate()).
const List<double> _saturate130 = [
  1.2362, -0.2145, -0.0217, 0, 0, //
  -0.0638, 1.0855, -0.0217, 0, 0, //
  -0.0638, -0.2145, 1.2783, 0, 0, //
  0, 0, 0, 1, 0, //
];

// -----------------------------------------------------------------------------
// Motion

/// Springs from the mockup's "Key transitions". Nothing pops in.
class Springs {
  Springs._();

  /// Check-in → Today. ~380 ms.
  static const SpringDescription checkIn = SpringDescription(mass: 1, stiffness: 260, damping: 28);

  /// Card → sheet. ~320 ms, drag velocity carried over.
  static const SpringDescription sheet = SpringDescription(mass: 1, stiffness: 300, damping: 30);

  /// Re-plan. ~400 ms.
  static const SpringDescription replan = SpringDescription(mass: 1, stiffness: 220, damping: 26);

  /// Ambience changes cross-fade over about 2 seconds.
  static const Duration ambience = Duration(seconds: 2);
}

/// A [Curve] that follows a spring from 0 to 1, for APIs that take a curve
/// and a duration. The duration should be the spring's settle time.
class SpringCurve extends Curve {
  SpringCurve(this.spring, this.duration);

  final SpringDescription spring;
  final Duration duration;

  late final SpringSimulation _sim = SpringSimulation(spring, 0, 1, 0);

  @override
  double transformInternal(double t) {
    final seconds = t * duration.inMicroseconds / Duration.microsecondsPerSecond;
    return _sim.x(seconds);
  }
}

/// Spring curves with their settle times, ready for implicit animations.
class Motion {
  Motion._();

  static const Duration checkInDuration = Duration(milliseconds: 380);
  static const Duration sheetDuration = Duration(milliseconds: 320);
  static const Duration replanDuration = Duration(milliseconds: 400);

  static final Curve checkIn = SpringCurve(Springs.checkIn, checkInDuration);
  static final Curve sheet = SpringCurve(Springs.sheet, sheetDuration);
  static final Curve replan = SpringCurve(Springs.replan, replanDuration);
}

// -----------------------------------------------------------------------------
// ThemeData

/// Material 3 underneath, customised so it doesn't look stock.
ThemeData buildTheme(Ambience ambience) {
  final brightness = ambience.brightness;
  final p = EnsoPalette.forBrightness(brightness);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accentInk,
    onSecondary: p.onAccent,
    error: p.ink,
    onError: p.background,
    surface: p.background,
    onSurface: p.ink,
    surfaceContainerHighest: p.sunk,
    outline: p.ink3,
    outlineVariant: p.line,
    shadow: p.shadow,
    scrim: p.scrim,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: EnsoType.family,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accentSoft,
      selectionHandleColor: p.accent,
    ),
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: EnsoType.family,
      bodyColor: p.ink,
      displayColor: p.ink,
    ),
  );
}

/// Status and navigation bar icons that suit the ambience, edge to edge.
SystemUiOverlayStyle overlayStyle(Brightness b) => SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
  statusBarIconBrightness: b == Brightness.light ? Brightness.dark : Brightness.light,
  statusBarBrightness: b,
  systemNavigationBarIconBrightness: b == Brightness.light ? Brightness.dark : Brightness.light,
);
