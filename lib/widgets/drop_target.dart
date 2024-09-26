import 'package:flutter/material.dart';
import 'package:shakepin/utils/drop_channel.dart';

class DropTarget extends StatefulWidget {
  const DropTarget({
    super.key,
    required this.label,
    required this.child,
    this.onDragPerform,
    this.onDragEnter,
    this.onDragExited,
    this.onDragConclude,
  });

  final String label;
  final Widget child;
  final Function(List<String> paths)? onDragPerform;
  final Function(Offset position)? onDragEnter;
  final Function()? onDragExited;
  final Function()? onDragConclude;

  @override
  State<DropTarget> createState() => _DropTargetState();
}

class _DropTargetState extends State<DropTarget> with DropListener {
  @override
  void initState() {
    super.label = widget.label;
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      if (!context.mounted) return;
      final renderObject = context.findRenderObject() as RenderBox?;
      if (renderObject == null) return;
      final offset = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      dropChannel.setDropTarget(offset & size, widget.label);
    });
    
    super.initState();
  }

  @override
  void dispose() {
    dropChannel.removeDropTarget(widget.label);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
