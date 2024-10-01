import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shakepin/widgets/drop_target.dart';

class DropHoverWidget extends StatefulWidget {
  const DropHoverWidget({
    super.key,
    required this.onDragPerform,
  });

  final Function(Set<String>) onDragPerform;

  @override
  State<DropHoverWidget> createState() => _DropHoverWidgetState();
}

class _DropHoverWidgetState extends State<DropHoverWidget> {
  var _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      label: 'pin',
      onDragEnter: (position) {
        setState(() {
          _isHovered = true;
        });
      },
      onDragExited: () {
        setState(() {
          _isHovered = false;
        });
      },
      onDragConclude: () {
        setState(() {
          _isHovered = false;
        });
      },
      onDragPerform: (paths) {
        widget.onDragPerform(paths.toSet());
      },
      child: ImageFiltered(
        imageFilter:
            ImageFilter.blur(sigmaX: 6, sigmaY: 6, tileMode: TileMode.mirror),
        child: Transform.scale(
          scaleX: (MediaQuery.sizeOf(context).width + 12) /
              MediaQuery.sizeOf(context).width,
          scaleY: (MediaQuery.sizeOf(context).height + 12) /
              MediaQuery.sizeOf(context).height,
          child: AnimatedContainer(
            duration: Durations.medium2,
            decoration: BoxDecoration(
              border: _isHovered
                  ? Border.all(
                      color: CupertinoColors.label.resolveFrom(context),
                      width: 6,
                      strokeAlign: BorderSide.strokeAlignInside,
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
