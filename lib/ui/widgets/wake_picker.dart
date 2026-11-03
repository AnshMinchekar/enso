import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../engine/models.dart';
import '../theme.dart';
import 'surfaces.dart';

/// Minute step of the wake picker.
const int kPickerMinuteStep = 5;

/// The calm wake-time picker: hours and 5-minute steps on two wheels, inside a
/// 232-high glass card with a sunk band behind the selected row.
class WakePicker extends StatelessWidget {
  const WakePicker({super.key, required this.value, required this.onChanged});

  /// Minutes are a multiple of [kPickerMinuteStep].
  final ClockTime value;
  final ValueChanged<ClockTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = EnsoPalette.of(context);
    return Glass(
      radius: Radii.hero,
      child: SizedBox(
        height: 232,
        child: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              top: 80,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.sunk,
                  borderRadius: BorderRadius.circular(Radii.small),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _Wheel(
                      semanticsLabel: 'Hour',
                      count: 24,
                      selected: value.hour,
                      alignEnd: true,
                      label: (i) => i.toString().padLeft(2, '0'),
                      onChanged: (h) => onChanged(ClockTime(h, value.minute)),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Text(
                    ':',
                    style: EnsoType.picker.copyWith(
                      fontSize: 52,
                      fontWeight: FontWeight.w200,
                      color: p.ink2,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _Wheel(
                      semanticsLabel: 'Minute',
                      count: 60 ~/ kPickerMinuteStep,
                      selected: value.minute ~/ kPickerMinuteStep,
                      alignEnd: false,
                      label: (i) => (i * kPickerMinuteStep).toString().padLeft(2, '0'),
                      onChanged: (m) => onChanged(ClockTime(value.hour, m * kPickerMinuteStep)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.count,
    required this.selected,
    required this.label,
    required this.onChanged,
    required this.alignEnd,
    required this.semanticsLabel,
  });

  final int count;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onChanged;
  final bool alignEnd;
  final String semanticsLabel;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> with SingleTickerProviderStateMixin {
  /// Pixels per item near the centre, used to turn drags into items.
  static const double _unit = 58;
  static const double _center = 116;

  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: widget.selected.toDouble(),
  )..addListener(_onMove);

  late int _lastIndex = widget.selected;

  @override
  void didUpdateWidget(_Wheel old) {
    super.didUpdateWidget(old);
    if (!_pos.isAnimating && _wrap(_pos.value.round()) != widget.selected) {
      _pos.value = widget.selected.toDouble();
      _lastIndex = widget.selected;
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  int _wrap(int i) => ((i % widget.count) + widget.count) % widget.count;

  void _onMove() {
    final i = _wrap(_pos.value.round());
    if (i != _lastIndex) {
      _lastIndex = i;
      HapticFeedback.selectionClick();
      widget.onChanged(i);
    }
    setState(() {});
  }

  void _snapTo(double target, double velocity) {
    _pos.animateWith(SpringSimulation(Springs.sheet, _pos.value, target, velocity));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = -d.velocity.pixelsPerSecond.dy / _unit;
    final projected = _pos.value + v * 0.3;
    _snapTo(projected.roundToDouble(), v);
  }

  void _step(int by) => _snapTo((_pos.value.round() + by).toDouble(), 0);

  /// Offset of an item [d] steps from the centre: rows are 72, 44, 36 tall.
  static double _offset(double d) {
    final a = d.abs();
    final o = a <= 1 ? 58 * a : (a <= 2 ? 58 + 40 * (a - 1) : 98 + 40 * (a - 2));
    return d.isNegative ? -o : o;
  }

  static double _lerp3(double a, double v0, double v1, double v2, double v3) {
    if (a <= 1) return lerpDouble(v0, v1, a)!;
    if (a <= 2) return lerpDouble(v1, v2, a - 1)!;
    if (a <= 3) return lerpDouble(v2, v3, a - 2)!;
    return v3;
  }

  @override
  Widget build(BuildContext context) {
    final base = EnsoType.picker.copyWith(color: EnsoPalette.of(context).ink);
    final pos = _pos.value;
    final first = pos.floor() - 3;
    return Semantics(
      label: widget.semanticsLabel,
      value: widget.label(widget.selected),
      increasedValue: widget.label(_wrap(widget.selected + 1)),
      decreasedValue: widget.label(_wrap(widget.selected - 1)),
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => _pos.stop(),
        onVerticalDragUpdate: (d) => _pos.value -= d.delta.dy / _unit,
        onVerticalDragEnd: _onDragEnd,
        onTapUp: (d) {
          final dy = d.localPosition.dy - _center;
          if (dy.abs() > 36) _step(dy > 0 ? (dy > 98 ? 2 : 1) : (dy < -98 ? -2 : -1));
        },
        child: ClipRect(
          child: SizedBox(
            height: 232,
            child: Stack(
              children: [for (var i = first; i <= first + 7; i++) _item(i, i - pos, base)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, double d, TextStyle base) {
    final a = d.abs();
    if (a > 3) return const SizedBox.shrink();
    final size = _lerp3(a, 60, 32, 24, 24);
    final opacity = _lerp3(a, 1, 0.45, 0.2, 0);
    return Positioned(
      left: 0,
      right: 0,
      top: _center + _offset(d) - 36,
      height: 72,
      child: Align(
        alignment: widget.alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Opacity(
          opacity: opacity,
          child: Text(
            widget.label(_wrap(i)),
            style: base.copyWith(fontSize: size, letterSpacing: a < 1 ? -0.02 * size * (1 - a) : 0),
          ),
        ),
      ),
    );
  }
}
