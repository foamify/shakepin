import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:desktop_drop/desktop_drop.dart' as drop;

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
    if (Platform.isWindows) {
      return drop.DropTarget(
        onDragEntered: (details) =>
            widget.onDragEnter?.call(details.globalPosition),
        onDragExited: (_) => widget.onDragExited?.call(),
        child: widget.child,
        onDragDone: (details) {
          print(details.files.map((e) => e.path).toList());
          widget.onDragPerform?.call(details.files.map((e) => e.path).toList());
          widget.onDragConclude?.call();
        },
      );
    }
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
  void onDragStart() async {
    final startTime = DateTime.now();
    RenderBox? renderObject;

    while (DateTime.now().difference(startTime).inSeconds < 1) {
      renderObject = context.findRenderObject() as RenderBox?;
      if (renderObject != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

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

  final List<Offset> positions = [];
  final List<DateTime> timestamps = [];

  bool detectShake() {
    if (positions.length < 3) return false;

    var horizontalChanges = 0;
    var verticalChanges = 0;
    var lastHorizontalDirection = 0;
    var lastVerticalDirection = 0;
    var totalDistance = 0.0;

    for (var i = 1; i < positions.length; i++) {
      final dx = positions[i].dx - positions[i - 1].dx;
      final dy = positions[i].dy - positions[i - 1].dy;

      final currentHorizontalDirection = dx == 0
          ? 0
          : dx > 0
              ? 1
              : -1;
      final currentVerticalDirection = dy == 0
          ? 0
          : dy > 0
              ? 1
              : -1;

      totalDistance += sqrt(dx * dx + dy * dy);

      if (lastHorizontalDirection != 0 &&
          currentHorizontalDirection != 0 &&
          currentHorizontalDirection != lastHorizontalDirection) {
        horizontalChanges++;
      }

      if (lastVerticalDirection != 0 &&
          currentVerticalDirection != 0 &&
          currentVerticalDirection != lastVerticalDirection) {
        verticalChanges++;
      }

      if (currentHorizontalDirection != 0) {
        lastHorizontalDirection = currentHorizontalDirection;
      }
      if (currentVerticalDirection != 0) {
        lastVerticalDirection = currentVerticalDirection;
      }
    }

    final duration =
        timestamps.last.difference(timestamps.first).inMilliseconds / 1000;
    final velocity = totalDistance / duration;

    return (horizontalChanges >= ShakeConfig.shakeThreshold ||
            verticalChanges >= ShakeConfig.shakeThreshold) &&
        velocity >= ShakeConfig.minVelocity;
  }

  @override
  void onLocationChange({
    required int hwnd,
    required int idObject,
    required int idChild,
    required int thread,
    required int time,
    required bool isShiftPressed,
  }) async {
    final currentPos = await screenRetriever.getCursorScreenPoint();
    final now = DateTime.now();

    // Check if shift key is pressed first
    if (isShiftPressed) {
      dropChannel.listeners.forEach((listener) {
        listener.shakeDetected(currentPos);
      });
      return;
    }

    positions.add(currentPos);
    timestamps.add(now);

    // Keep only recent movements within time window
    while (timestamps.isNotEmpty &&
        now.difference(timestamps.first) > ShakeConfig.timeWindow) {
      positions.removeAt(0);
      timestamps.removeAt(0);
    }

    if (detectShake()) {
      dropChannel.listeners.forEach((listener) {
        listener.shakeDetected(currentPos);
      });
      positions.clear();
      timestamps.clear();
    }
  }
}

/// Shake detection configuration
class ShakeConfig {
  static const int shakeThreshold = 4; // Direction changes needed
  static const Duration timeWindow =
      Duration(seconds: 1); // Time window for shake
  static const double minVelocity = 200.0; // Pixels per second
}
