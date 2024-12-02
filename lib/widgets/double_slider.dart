import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

const double _kSliderMinWidth = 180.0;
const double _kContinuousThumbSize = 16.0;
const double _kDiscreteThumbWidth = 4.0;
const double _kOverallHeight = 28.0;

class MacosDoubleSlider extends StatefulWidget {
  const MacosDoubleSlider({
    super.key,
    required this.startValue,
    required this.endValue,
    required this.onChanged,
    this.discrete = false,
    this.splits = 15,
    this.min = 0.0,
    this.max = 1.0,
    this.color = CupertinoColors.systemBlue,
    this.backgroundColor = MacosColors.sliderBackgroundColor,
    this.tickBackgroundColor = MacosColors.tickBackgroundColor,
    this.thumbColor = MacosColors.sliderThumbColor,
    this.semanticLabel,
  })  : assert(startValue >= min && startValue <= max),
        assert(endValue >= min && endValue <= max),
        assert(startValue <= endValue),
        assert(min < max),
        assert(splits >= 2);

  final double startValue;
  final double endValue;
  final void Function(double startValue, double endValue) onChanged;
  final bool discrete;
  final double min;
  final double max;
  final int splits;
  final Color backgroundColor;
  final Color tickBackgroundColor;
  final Color color;
  final Color thumbColor;
  final String? semanticLabel;

  @override
  State<MacosDoubleSlider> createState() => _MacosDoubleSliderState();
}

class _MacosDoubleSliderState extends State<MacosDoubleSlider> {
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;

  double initialPosition = 0;

  double _startPercentage() {
    if (widget.discrete) {
      final double splitPercentage = 1 / (widget.splits - 1);
      final int splitIndex = (widget.startValue / splitPercentage).round();
      return splitIndex * splitPercentage;
    } else {
      return (widget.startValue - widget.min) / (widget.max - widget.min);
    }
  }

  double _endPercentage() {
    if (widget.discrete) {
      final double splitPercentage = 1 / (widget.splits - 1);
      final int splitIndex = (widget.endValue / splitPercentage).round();
      return splitIndex * splitPercentage;
    } else {
      return (widget.endValue - widget.min) / (widget.max - widget.min);
    }
  }

  void _updateValue(double sliderWidth, double localPosition, bool isStart) {
    double newValue;
    if (widget.discrete) {
      final double splitPercentage = 1 / (widget.splits - 1);
      final int splitIndex = (localPosition / sliderWidth / splitPercentage)
          .round()
          .clamp(0, widget.splits - 1);
      newValue =
          splitIndex * splitPercentage * (widget.max - widget.min) + widget.min;
    } else {
      newValue = (localPosition / sliderWidth) * (widget.max - widget.min) +
          widget.min;
      newValue = newValue.clamp(widget.min, widget.max);
    }

    if (isStart) {
      if (newValue <= widget.endValue) {
        widget.onChanged(newValue, widget.endValue);
      }
    } else {
      if (newValue >= widget.startValue) {
        widget.onChanged(widget.startValue, newValue);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value:
          '${widget.startValue.toStringAsFixed(2)} to ${widget.endValue.toStringAsFixed(2)}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _kSliderMinWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double width = constraints.maxWidth;
            if (width.isInfinite) width = _kSliderMinWidth;

            double horizontalPadding = widget.discrete
                ? _kDiscreteThumbWidth / 2
                : _kContinuousThumbSize / 2;
            width -= horizontalPadding * 2;

            return SizedBox(
              height: _kOverallHeight,
              child: Stack(
                children: [
                  // Background track
                  Positioned(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: (_kOverallHeight - 2) / 2,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: MacosDynamicColor.resolve(
                          widget.backgroundColor,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Selected range track
                  Positioned(
                    left: horizontalPadding + width * _startPercentage(),
                    right: horizontalPadding + width * (1 - _endPercentage()),
                    top: (_kOverallHeight - 2) / 2,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Start thumb
                  Positioned(
                    left: horizontalPadding +
                        width * _startPercentage() -
                        _kContinuousThumbSize / 2,
                    top: (_kOverallHeight - _kContinuousThumbSize) / 2,
                    child: _buildStartThumb(width, context, isLeftHalf: false),
                  ),
                  // End thumb
                  Positioned(
                    left: horizontalPadding +
                        width * _endPercentage() -
                        _kContinuousThumbSize / 2,
                    top: (_kOverallHeight - _kContinuousThumbSize) / 2,
                    child: _buildEndThumb(width, context, isLeftHalf: true),
                  ),
                  // Start thumb
                  Positioned(
                    left: horizontalPadding +
                        width * _startPercentage() -
                        _kContinuousThumbSize / 2,
                    top: (_kOverallHeight - _kContinuousThumbSize) / 2,
                    child: _buildStartThumb(width, context, isLeftHalf: true),
                  ),
                  // End thumb
                  Positioned(
                    left: horizontalPadding +
                        width * _endPercentage() -
                        _kContinuousThumbSize / 2,
                    top: (_kOverallHeight - _kContinuousThumbSize) / 2,
                    child: _buildEndThumb(width, context, isLeftHalf: false),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  ClipRect _buildEndThumb(
    double width,
    BuildContext context, {
    required bool isLeftHalf,
  }) {
    return ClipRect(
      clipper: RectangleClipper(
        isLeftHalf
            ? const Rect.fromLTWH(
                0,
                0,
                _kContinuousThumbSize / 2,
                _kContinuousThumbSize,
              )
            : const Rect.fromLTWH(
                _kContinuousThumbSize / 2,
                0,
                _kContinuousThumbSize / 2,
                _kContinuousThumbSize,
              ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          _isDraggingEnd = true;
          initialPosition = _endPercentage() * width;
        },
        onHorizontalDragUpdate: (details) {
          if (_isDraggingEnd) {
            _updateValue(
                width,
                initialPosition +
                    details.localPosition.dx -
                    _kContinuousThumbSize / 2,
                false);
          }
        },
        onHorizontalDragEnd: (_) => _isDraggingEnd = false,
        child: Container(
          width: _kContinuousThumbSize,
          height: _kContinuousThumbSize,
          decoration: BoxDecoration(
            color: MacosDynamicColor.resolve(widget.thumbColor, context),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  ClipRect _buildStartThumb(
    double width,
    BuildContext context, {
    required bool isLeftHalf,
  }) {
    return ClipRect(
      clipper: RectangleClipper(
        isLeftHalf
            ? const Rect.fromLTWH(
                0,
                0,
                _kContinuousThumbSize / 2,
                _kContinuousThumbSize,
              )
            : const Rect.fromLTWH(
                _kContinuousThumbSize / 2,
                0,
                _kContinuousThumbSize,
                _kContinuousThumbSize,
              ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          _isDraggingStart = true;
          initialPosition = _startPercentage() * width;
        },
        onHorizontalDragUpdate: (details) {
          if (_isDraggingStart) {
            _updateValue(
                width,
                initialPosition +
                    details.localPosition.dx -
                    _kContinuousThumbSize / 2,
                true);
          }
        },
        onHorizontalDragEnd: (_) => _isDraggingStart = false,
        child: Container(
          width: _kContinuousThumbSize,
          height: _kContinuousThumbSize,
          decoration: BoxDecoration(
            color: MacosDynamicColor.resolve(widget.thumbColor, context),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class RectangleClipper extends CustomClipper<Rect> {
  final Rect rect;

  RectangleClipper(this.rect);

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(RectangleClipper oldClipper) => rect != oldClipper.rect;
}
