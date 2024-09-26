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
      child: Container(),
    );
  }
}
