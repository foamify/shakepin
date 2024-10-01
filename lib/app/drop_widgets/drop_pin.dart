import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_hover.dart';
import 'package:shakepin/widgets/drop_target.dart';

class DropPin extends StatefulWidget {
  const DropPin({super.key, required this.icon});

  final Widget icon;

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
        dropChannel.showPopover('Drop files here to pin them');
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
        dropChannel.hidePopover();
        setState(() {
          _isHovered = false;
        });
      },
      onDragPerform: (paths) async {
        items.value = paths.toSet();

        dropChannel.setFrame(
          Rect.fromCenter(
            center: await dropChannel.center(),
            width: AppSizes.pin.width,
            height: AppSizes.pin.height,
          ),
          animate: true,
        );
      },
      child: DropHover(
        isHovered: _isHovered,
        child: widget.icon,
      ),
    );
  }
}
