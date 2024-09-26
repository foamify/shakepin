import 'package:flutter/material.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

class DropTarget extends StatefulWidget {
  const DropTarget({
    super.key,
    required this.label,
    required this.child,
    this.onDragPerform,
    this.onDragEnter,
    this.onDragExited,
    this.onDragConclude,
    this.onDraggingUpdated,
    this.shakeDetected,
  });

  final String label;
  final Widget child;
  final Function(List<String> paths)? onDragPerform;
  final Function(Offset position)? onDragEnter;
  final Function()? onDragExited;
  final Function()? onDragConclude;
  final Function(Offset position)? onDraggingUpdated;
  final Function(Offset position)? shakeDetected;

  @override
  State<DropTarget> createState() => _DropTargetState();
}

class _DropTargetState extends State<DropTarget> implements DropListener {
  @override
  void initState() {
    dropChannel.addListener(this);
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      if (!mounted || !context.mounted) return;
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
    dropChannel.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  String get label => widget.label;

  @override
  void onDragConclude() {
    widget.onDragConclude?.call();
  }

  @override
  void onDragEnter(Offset position) {
    haptic.levelChange();
    widget.onDragEnter?.call(position);
  }

  @override
  void onDragExited() {
    widget.onDragExited?.call();
  }

  @override
  void onDragPerform(List<String> paths) {
    widget.onDragPerform?.call(paths);
  }

  @override
  void onDraggingUpdated(Offset position) {
    widget.onDraggingUpdated?.call(position);
  }

  @override
  void shakeDetected(Offset position) {
    widget.shakeDetected?.call(position);
  }

  @override
  set label(String label) {}
}
