import 'package:flutter/cupertino.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_target.dart';
import 'package:shakepin/widgets/drop_button_hover.dart';

class DropMisc extends StatefulWidget {
  const DropMisc({super.key, required this.icon});

  final Widget icon;

  @override
  State<DropMisc> createState() => _DropMiscState();
}

class _DropMiscState extends State<DropMisc> {
  var _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      label: 'drop-misc-btn',
      onDragEnter: (position) {
        dropChannel.showPopover('Drop files here to open other tools');
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
        
        isMiscApp.value = true;
        dropChannel.setFrame(
          Rect.fromCenter(
            center: await dropChannel.center(),
            width: AppSizes.misc.width,
            height: AppSizes.misc.height,
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
