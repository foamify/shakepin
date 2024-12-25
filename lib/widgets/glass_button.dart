import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/utils.dart';

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.radius,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.secondary = false,
  });

  final Widget child;
  final void Function()? onTap;
  final double? radius;
  final EdgeInsets padding;
  final bool secondary;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.secondary
        ? MacosColors.controlColor.resolvedColor(context)
        : MacosColors.controlAccentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() {
          _isPressed = false;
          widget.onTap?.call();
        }),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? .97 : 1,
          duration: Durations.short2,
          curve: Curves.fastEaseInToSlowEaseOut,
          child: LayoutBuilder(builder: (context, constraints) {
            final radius = widget.radius ??
                [constraints.maxWidth, constraints.maxHeight, 48.0]
                    .where((value) => value.isFinite && value > 0)
                    .fold<double>(0.0, (a, b) => a > b ? a : b);
            return AnimatedContainer(
              // width: 48,
              // height: 48,
              duration: Durations.medium4,
              curve: Curves.fastEaseInToSlowEaseOut,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: buttonColor),
              foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  // border: Border.all(
                  //   strokeAlign: -2.0,
                  //   color: _isHovered
                  //       ? Colors.transparent
                  //       : MacosColors.controlColor.resolvedColor(context),
                  // ),
                  color: _isHovered
                      ? MacosColors.controlColor.resolvedColor(context)
                      : null),
              child: AnimatedScale(
                scale: _isHovered ? 1.1 : 1,
                duration: Durations.long4,
                curve: Curves.elasticOut,
                child: IconTheme(
                  data: IconThemeData(
                    color: MacosColors.labelColor.resolveFrom(context),
                    opacity: _isHovered ? 1 : 0.8,
                  ),
                  child: Center(
                      child: Padding(
                    padding: widget.padding,
                    child: widget.child,
                  )),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
