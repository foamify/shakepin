import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_hover.dart';
import 'package:shakepin/widgets/drop_target.dart';

class DropMinify extends StatefulWidget {
  const DropMinify({super.key, required this.icon});

  final Widget icon;

  @override
  State<DropMinify> createState() => _DropMinifyState();
}

class _DropMinifyState extends State<DropMinify> {
  var _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      label: 'drop-minify-btn',
      onDragEnter: (details) {
        dropChannel.showPopover('Drop images and videos here to minify their size');
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
        items.value = items().union(paths.toSet());
        isMinifyApp.value = true;
        dropChannel.setFrame(
          Rect.fromCenter(
            center: await dropChannel.center(),
            width: AppSizes.minify.width,
            height: AppSizes.minify.height,
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
