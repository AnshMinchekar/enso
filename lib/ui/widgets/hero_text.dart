import 'package:flutter/material.dart';

/// A line of text that flies between screens as a shared element, blending
/// its size, weight and colour from the source style to the destination style.
class HeroText extends StatelessWidget {
  const HeroText({
    super.key,
    required this.tag,
    required this.text,
    required this.style,
    this.maxLines = 2,
    this.enabled = true,
  });

  final String tag;
  final String text;
  final TextStyle style;
  final int maxLines;

  /// Off for rows that are animating out, so two heroes never share a tag.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final body = _HeroTextBody(text: text, style: style, maxLines: maxLines);
    if (!enabled) return body;
    return Hero(
      tag: tag,
      // Keep the name visible under the scrim while its copy is in the sheet.
      placeholderBuilder: (context, size, child) => child,
      flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
        final from = (fromContext.widget as Hero).child as _HeroTextBody;
        final to = (toContext.widget as Hero).child as _HeroTextBody;
        // The animation runs 0→1 on push and 1→0 on pop. On push `from` is
        // the hero on the route below; on pop it is the one being closed.
        final below = direction == HeroFlightDirection.push ? from : to;
        final above = direction == HeroFlightDirection.push ? to : from;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) => _HeroTextBody(
            text: above.text,
            style: TextStyle.lerp(below.style, above.style, animation.value)!,
            maxLines: above.maxLines,
          ),
        );
      },
      child: body,
    );
  }
}

class _HeroTextBody extends StatelessWidget {
  const _HeroTextBody({required this.text, required this.style, required this.maxLines});

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
      ),
    ),
  );
}
