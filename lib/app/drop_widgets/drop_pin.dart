import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shakepin/widgets/drop_target.dart';

class DropPin extends StatefulWidget {
  const DropPin({super.key});

  @override
  State<DropPin> createState() => _DropPinState();
}

class _DropPinState extends State<DropPin> {
  var _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      label: 'drop-pin-btn',
      onDragEnter: (details) {
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
        print(paths);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          border: _isHovered
              ? null
              : Border.all(color: CupertinoColors.systemGrey6),
          borderRadius: BorderRadius.circular(_isHovered ? 10 : 12),
          boxShadow: _isHovered
              ? [
                  const BoxShadow(
                    color: CupertinoColors.systemGrey6,
                    offset: Offset(0, 0),
                    blurRadius: 10,
                    spreadRadius: 10,
                  ),
                ]
              : null,
        ),
        child: const Text('Drop Pin'),
      ),
    );
  }
}
