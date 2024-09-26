import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_hover.dart';
import 'package:shakepin/widgets/drop_target.dart';

class DropArchive extends StatefulWidget {
  const DropArchive({super.key, required this.icon});

  final Widget icon;

  @override
  State<DropArchive> createState() => _DropArchiveState();
}

class _DropArchiveState extends State<DropArchive> {
  var _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      label: 'drop-archive-btn',
      onDragEnter: (details) {
        print('onDragEnter');
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
      onDragPerform: (paths) async {
        items.value = items().union(paths.toSet());
        archiveProgress.value = 0;
        dropChannel.setFrame(
          Rect.fromCenter(
            center: await dropChannel.center(),
            width: AppSizes.archive.width,
            height: AppSizes.archive.height,
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
