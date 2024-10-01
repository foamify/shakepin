import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DropHover extends StatefulWidget {
  const DropHover({
    super.key,
    required this.isHovered,
    required this.child,
  });

  final bool isHovered;
  final Widget child;

  @override
  State<DropHover> createState() => _DropHoverState();
}

class _DropHoverState extends State<DropHover> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: AnimatedContainer(
        width: 48,
        height: 48,
        duration: Durations.short4,
        foregroundDecoration: BoxDecoration(
          border: widget.isHovered
              ? null
              : Border.all(
                  color: CupertinoColors.label
                      .resolveFrom(context)
                      .withOpacity(0.5)),
          borderRadius: BorderRadius.circular(widget.isHovered ? 8 : 10),
          boxShadow: widget.isHovered
              ? [
                  BoxShadow(
                    color: CupertinoColors.label.resolveFrom(context),
                    blurStyle: BlurStyle.outer,
                    offset: Offset.zero,
                    blurRadius: 5,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: AnimatedScale(
          scale: widget.isHovered ? 1.1 : 1,
          duration: Durations.short4,
          child: widget.child,
        ),
      ),
    );
  }
}