import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

/// Thin, rounded line icons from the mockups, drawn from their SVG paths on a
/// 24 × 24 grid.
enum LineIcons {
  settings(
    'M4 7h10M18 7h2M4 17h4M12 17h8'
    'M14 7a2 2 0 1 0 4 0a2 2 0 1 0 -4 0'
    'M8 17a2 2 0 1 0 4 0a2 2 0 1 0 -4 0',
  ),
  clock('M3.5 12a8.5 8.5 0 1 0 17 0a8.5 8.5 0 1 0 -17 0M12 7.5V12l3 2'),
  close('M7 7l10 10M17 7L7 17'),
  plus('M12 5v14M5 12h14'),
  check('M5 12.5l4.5 4.5L19 7.5', strokeWidth: 2),
  moon('M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z', strokeWidth: 1.2),
  bell('M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0'),
  back('M15 6l-6 6 6 6'),
  chevron('M10 6l6 6-6 6'),
  file('M7 3h7l5 5v13H7zM14 3v5h5'),
  clipboard(
    'M7.5 4.5h9a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-9a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2zM9 3.5h6v3H9z',
  ),
  chat(
    'M5 5h14a1.5 1.5 0 0 1 1.5 1.5v9A1.5 1.5 0 0 1 19 17h-8l-4.5 3.5V17H5'
    'a1.5 1.5 0 0 1-1.5-1.5v-9A1.5 1.5 0 0 1 5 5z',
  );

  const LineIcons(this.data, {this.strokeWidth = 1.5});

  final String data;
  final double strokeWidth;
}

class LineIcon extends StatelessWidget {
  const LineIcon(this.icon, {super.key, this.size = 22, this.color, this.strokeWidth});

  final LineIcons icon;
  final double size;

  /// Defaults to the ambient text colour.
  final Color? color;

  /// Overrides the icon's own stroke width (in 24-grid units).
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LineIconPainter(icon.data, c, strokeWidth ?? icon.strokeWidth)),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  _LineIconPainter(this.data, this.color, this.strokeWidth);

  final String data;
  final Color color;
  final double strokeWidth;

  static final Map<String, Path> _cache = {};

  static Path _path(String data) => _cache.putIfAbsent(data, () {
    final proxy = _PathProxy();
    writeSvgPathDataToPath(data, proxy);
    return proxy.path;
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    canvas.drawPath(
      _path(data),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_LineIconPainter old) =>
      old.data != data || old.color != color || old.strokeWidth != strokeWidth;
}

class _PathProxy extends PathProxy {
  final Path path = Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}
