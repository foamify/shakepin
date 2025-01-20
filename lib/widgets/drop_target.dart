import 'package:flutter/material.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

class DropTarget extends StatefulWidget {
  const DropTarget({
    super.key,
    required this.label,
    required this.child,
    this.onDragStart,
    this.onDragPerform,
    this.onDragEnter,
    this.onDragExited,
    this.onDragConclude,
    this.onDraggingUpdated,
    this.shakeDetected,
    this.onDragSessionEnded,
  });

  final String label;
  final Widget child;

  /// Called when user starts dragging a file or an item from anywhere.
  final Function(Offset position)? onDragStart;
  final Function(List<String> paths)? onDragPerform;
  final Function(Offset position)? onDragEnter;
  final Function()? onDragExited;
  final Function()? onDragConclude;
  final Function(Offset position)? onDraggingUpdated;
  final Function(Offset position)? shakeDetected;
  final Function(DropOperation operation)? onDragSessionEnded;

  @override
  State<DropTarget> createState() => _DropTargetState();
}

class _DropTargetState extends State<DropTarget> implements DragDropListener {
  var isDragging = false;

  @override
  void initState() {
    dropChannel.addListener(this);

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
    Future.delayed(Durations.short4, () {
      dropChannel.removeDropTarget(widget.label);
    });
    widget.onDragConclude?.call();
  }

  @override
  void onDragStart() {
    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null) return;
    final offset = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    dropChannel.setDropTarget(offset & size, widget.label);

    widget.onDragStart?.call(Offset.zero);
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
    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null) return;
    final offset = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    dropChannel.setDropTarget(offset & size, widget.label);

    widget.shakeDetected?.call(position);
  }

  @override
  void onDragSessionEnded(DropOperation operation) {
    widget.onDragSessionEnded?.call(operation);
  }

  @override
  set label(String label) {}
}
