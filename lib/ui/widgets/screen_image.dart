import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart';

/// The current look, for widgets that draw the background themselves (glass
/// panels, bottom fades). Changes only when the ambience changes, so these
/// widgets don't rebuild on every tap.
class AmbienceScope extends InheritedWidget {
  const AmbienceScope({
    super.key,
    required this.ambience,
    required this.night,
    required super.child,
  });

  final Ambience ambience;

  /// Wind down: the solid night colour is showing instead of artwork.
  final bool night;

  static AmbienceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmbienceScope>();

  @override
  bool updateShouldNotify(AmbienceScope old) => old.ambience != ambience || old.night != night;
}

/// Paints [asset] the way the full-screen background paints it (cover fit,
/// centred on the screen), clipped to this widget's box. A panel therefore
/// shows exactly the patch of background behind it, without reading back
/// the screen. [child] paints on top.
class ScreenImage extends StatefulWidget {
  const ScreenImage({super.key, required this.asset, this.borderRadius, this.child});

  final String asset;
  final BorderRadius? borderRadius;
  final Widget? child;

  @override
  State<ScreenImage> createState() => _ScreenImageState();
}

class _ScreenImageState extends State<ScreenImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() {
      _info?.dispose();
      _info = info;
    });
  });
  ScrollPosition? _scroll;
  final _boxKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
    // Scrolled content can be moved without repainting; follow the scroll so
    // the background stays aligned with the screen.
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_repaint);
      _scroll = scroll?..addListener(_repaint);
    }
  }

  @override
  void didUpdateWidget(ScreenImage old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) _resolve();
  }

  void _resolve() {
    final stream = AssetImage(widget.asset).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _repaint() =>
      (_boxKey.currentContext?.findRenderObject() as _RenderScreenImage?)?.markNeedsPaint();

  @override
  void dispose() {
    _scroll?.removeListener(_repaint);
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ScreenImageBox(
    key: _boxKey,
    image: _info?.image,
    screen: MediaQuery.sizeOf(context),
    borderRadius: widget.borderRadius,
    child: widget.child,
  );
}

class _ScreenImageBox extends SingleChildRenderObjectWidget {
  const _ScreenImageBox({
    super.key,
    required this.image,
    required this.screen,
    this.borderRadius,
    super.child,
  });

  final ui.Image? image;
  final Size screen;
  final BorderRadius? borderRadius;

  @override
  _RenderScreenImage createRenderObject(BuildContext context) =>
      _RenderScreenImage(image, screen, borderRadius);

  @override
  void updateRenderObject(BuildContext context, _RenderScreenImage r) {
    r
      ..image = image
      ..screen = screen
      ..borderRadius = borderRadius;
  }
}

class _RenderScreenImage extends RenderProxyBox {
  _RenderScreenImage(this._image, this._screen, this._borderRadius);

  ui.Image? _image;
  set image(ui.Image? v) {
    if (identical(v, _image)) return;
    _image = v;
    markNeedsPaint();
  }

  Size _screen;
  set screen(Size v) {
    if (v == _screen) return;
    _screen = v;
    markNeedsPaint();
  }

  BorderRadius? _borderRadius;
  set borderRadius(BorderRadius? v) {
    if (v == _borderRadius) return;
    _borderRadius = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final image = _image;
    if (image != null && !size.isEmpty) {
      final canvas = context.canvas;
      final origin = localToGlobal(Offset.zero);
      final iw = image.width.toDouble();
      final ih = image.height.toDouble();
      final scale = math.max(_screen.width / iw, _screen.height / ih);
      final w = iw * scale;
      final h = ih * scale;
      final dst = Rect.fromLTWH(
        offset.dx - origin.dx + (_screen.width - w) / 2,
        offset.dy - origin.dy + (_screen.height - h) / 2,
        w,
        h,
      );
      final box = offset & size;
      canvas.save();
      final r = _borderRadius;
      if (r == null) {
        canvas.clipRect(box);
      } else {
        canvas.clipRRect(r.toRRect(box));
      }
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, iw, ih),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }
    super.paint(context, offset);
  }
}

/// Fades a scrolling area out at the bottom by painting the background over
/// its last stretch, instead of masking the whole scrolling layer every
/// frame.
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, required this.child, this.from = 0.8});

  final Widget child;

  /// Where the fade starts, as a fraction of the height.
  final double from;

  @override
  Widget build(BuildContext context) {
    final scope = AmbienceScope.maybeOf(context);
    if (scope == null || scope.night) return child;
    final a = scope.ambience;
    final wash = Backdrops.wash(a);
    return LayoutBuilder(
      builder: (context, c) {
        final fade = c.maxHeight.isFinite ? c.maxHeight * (1 - from) : 120.0;
        return Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: fade,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xFF000000)],
                    ).createShader(rect),
                    child: ScreenImage(
                      asset: Backdrops.asset(a),
                      child: wash == null ? const SizedBox.expand() : ColoredBox(color: wash),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
