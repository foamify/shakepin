library wearos_curved_scrollbar;

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';

class CurvedScrollbar extends StatefulWidget {
  final Widget child;
  final Color color;
  final double blockThickness;
  final double trackWidth;
  final ScrollController controller;
  final bool hideOnNoScroll;
  final double cornerRadius;

  const CurvedScrollbar({
    super.key,
    required this.child,
    required this.controller,
    this.color = Colors.grey,
    this.blockThickness = 4.0,
    this.trackWidth = 8.0,
    this.hideOnNoScroll = true,
    this.cornerRadius = 4.0,
  });

  @override
  _CurvedScrollbarState createState() => _CurvedScrollbarState();
}

class _CurvedScrollbarState extends State<CurvedScrollbar>
    with SingleTickerProviderStateMixin {
  Timer? _hideTimer;
  late AnimationController _animationController;
  double scrollPixels = 0.0;
  double scrollMaxPixels = 0.0;
  double scrollbarHeight = 0.0;
  Offset _scrollStartPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: widget.hideOnNoScroll ? 0.0 : 1.0,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _showScrollbar() {
    if (_hideTimer?.isActive ?? false) {
      _hideTimer!.cancel();
    }
    setState(() {
      _animationController.forward();
    });
    _hideTimer = Timer(const Duration(seconds: 1), () {
      _animationController.reverse().then((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        scrollPixels = scrollInfo.metrics.pixels;
        scrollMaxPixels = widget.controller.position.maxScrollExtent;

        // Calculate scrollbar height considering the corner radius boundaries
        final availableHeight = widget.controller.position.viewportDimension -
            (2 * widget.cornerRadius);
        scrollbarHeight =
            (availableHeight / widget.controller.position.maxScrollExtent) *
                availableHeight;

        // Calculate scroll position taking into account the corner radius offset
        _scrollStartPos = Offset(
          0,
          widget.cornerRadius +
              (math.max(scrollInfo.metrics.pixels, 0.0) /
                  widget.controller.position.maxScrollExtent *
                  availableHeight),
        );

        _showScrollbar();
        setState(() {});
        return true;
      },
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _animationController,
                child: CustomPaint(
                  painter: CurvedScrollbarPainter(
                    controller: widget.controller,
                    color: widget.color,
                    blockThickness: widget.blockThickness,
                    trackWidth: widget.trackWidth,
                    cornerRadius: widget.cornerRadius,
                    scrollbarHeight: scrollbarHeight,
                    overScrollPixels: scrollPixels.sign == -1
                        ? scrollPixels
                        : scrollMaxPixels < scrollPixels
                            ? scrollPixels - scrollMaxPixels
                            : 0.0,
                    scrollStartPos: _scrollStartPos,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CurvedScrollbarPainter extends CustomPainter {
  final ScrollController controller;
  final Color color;
  final double blockThickness;
  final double trackWidth;
  final double cornerRadius;
  final double scrollbarHeight;
  final double overScrollPixels;
  final Offset scrollStartPos;

  CurvedScrollbarPainter({
    required this.controller,
    required this.color,
    required this.blockThickness,
    required this.trackWidth,
    required this.cornerRadius,
    required this.scrollbarHeight,
    required this.overScrollPixels,
    required this.scrollStartPos,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    if (!controller.hasClients) return;

    final thumbPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = blockThickness;

    final pathToFollow = Path()
      ..moveTo(size.width - cornerRadius, trackWidth)
      ..arcToPoint(
        Offset(size.width - trackWidth, cornerRadius),
        clockwise: true,
        radius: Radius.circular(cornerRadius - trackWidth),
      )
      ..lineTo(size.width - trackWidth, size.height - cornerRadius)
      ..arcToPoint(
        Offset(size.width - cornerRadius, size.height - trackWidth),
        clockwise: true,
        radius: Radius.circular(cornerRadius - trackWidth),
      );

    final PathMetrics metrics = pathToFollow.computeMetrics();
    final PathMetric pathMetric = metrics.first;
    final double pathLength = pathMetric.length;

    // Calculate the scrollable portion of the path (between corner radii)
    final double availablePathLength = pathLength - (cornerRadius);

    // Scale thumb length relative to available path length
    final double scaledThumbLength =
        (scrollbarHeight / controller.position.viewportDimension) *
            availablePathLength;

    // Calculate start position including overscroll
    double effectiveStart = cornerRadius +
        (scrollStartPos.dy - cornerRadius) / size.height * availablePathLength;

    // Handle overscroll
    if (overScrollPixels != 0) {
      final double overscrollAmount =
          (overScrollPixels / size.height) * availablePathLength;
      // effectiveStart += overscrollAmount / 2;
    }

    var pathStart = effectiveStart;
    var pathEnd = (effectiveStart + scaledThumbLength);

    final double overscrollAmount =
        (overScrollPixels / size.height) * availablePathLength;

    if (overScrollPixels < 0) {
      pathStart += overscrollAmount / 2;
      pathEnd += overscrollAmount / 8;
    }

    if (overScrollPixels > 0) {
      pathStart += overscrollAmount / 8;
      pathEnd += overscrollAmount / 2;
    }

    final Path thumbPath = Path();
    thumbPath.addPath(
      pathMetric.extractPath(
        // pathStart.clamp(.0, pathLength - scaledThumbLength),
        // pathEnd.clamp(scaledThumbLength, pathLength),
        pathStart.clamp(.0, pathLength),
        pathEnd.clamp(.0, pathLength),
      ),
      Offset.zero,
    );

    canvas.drawPath(thumbPath, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
