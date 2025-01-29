import 'dart:math' as math;
import 'package:flutter/material.dart';

class SupportBanner extends StatefulWidget {
  const SupportBanner({super.key});

  @override
  State<SupportBanner> createState() => _SupportBannerState();
}

class _SupportBannerState extends State<SupportBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 24,
      end: 48,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(140, 140),
            painter: _SupportBannerPainter(
              bannerWidth: 100,
              bannerHeight: 12,
              offset: const Offset(90, 40),
              fontSize: 12 - _glowAnimation.value / 48,
              blurRadius: _glowAnimation.value,
            ),
          );
        },
      ),
    );
  }
}

class _SupportBannerPainter extends CustomPainter {
  const _SupportBannerPainter({
    this.bannerWidth = 100,
    this.bannerHeight = 24,
    this.offset = const Offset(50, 50), // Default offset as Offset
    this.fontSize = 12,
    this.blurRadius = 48,
  });

  final double bannerWidth;
  final double bannerHeight;
  final Offset offset;
  final double fontSize;
  final double blurRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      -offset.dx - 36,
      offset.dy - bannerHeight,
      bannerWidth + 80,
      bannerHeight,
    );

    // Shadow paint
    final shadowPaint = BoxShadow(
      color: Colors.red,
      blurRadius: blurRadius,
    ).toPaint();

    // Banner paint
    final bannerPaint = Paint()..color = Colors.red;

    // Text painter
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'damywise.com',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    canvas
      ..translate(offset.dx, size.height - offset.dy)
      ..rotate(math.pi / 4)
      ..drawRect(rect, shadowPaint)
      ..drawRect(rect, bannerPaint);

    // Layout and paint text
    textPainter.layout(maxWidth: bannerWidth);
    textPainter.paint(
      canvas,
      rect.topLeft +
          Offset(
            (rect.width - textPainter.width) / 2,
            (rect.height - textPainter.height) / 2,
          ),
    );

    textPainter.dispose();
  }

  @override
  bool shouldRepaint(_SupportBannerPainter oldDelegate) {
    return bannerWidth != oldDelegate.bannerWidth ||
        bannerHeight != oldDelegate.bannerHeight ||
        offset != oldDelegate.offset ||
        fontSize != oldDelegate.fontSize ||
        blurRadius != oldDelegate.blurRadius;
  }

  @override
  bool hitTest(Offset position) => false;
}
