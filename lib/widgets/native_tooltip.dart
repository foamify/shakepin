import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TooltipManager {
  static final Map<String, _NativeTooltipState> _tooltips = {};
  static int _counter = 0;

  static String registerTooltip(_NativeTooltipState state) {
    final id = 'tooltip_${_counter++}';
    _tooltips[id] = state;
    return id;
  }

  static void unregisterTooltip(String id) {
    _tooltips.remove(id);
  }
}

class NativeTooltip extends StatefulWidget {
  final Widget child;
  final String message;

  const NativeTooltip({
    super.key,
    required this.child,
    required this.message,
  });

  @override
  State<NativeTooltip> createState() => _NativeTooltipState();
}

class _NativeTooltipState extends State<NativeTooltip> {
  static const tooltipChannel = MethodChannel('click.shakepin.macos/tooltip');
  late final String tooltipId;

  @override
  void initState() {
    super.initState();
    tooltipId = TooltipManager.registerTooltip(this);
  }

  @override
  void dispose() {
    _updateNativeTooltip(remove: true);
    TooltipManager.unregisterTooltip(tooltipId);
    super.dispose();
  }

  void _updateNativeTooltip({bool remove = false}) {
    if (!Platform.isMacOS) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    tooltipChannel.invokeMethod('updateTooltip', {
      'tooltipId': tooltipId,
      'text': widget.message,
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
      'remove': remove,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return Tooltip(
        message: widget.message,
        child: widget.child,
      );
    }

    return MouseRegion(
      onEnter: (_) => _updateNativeTooltip(),
      onExit: (_) => _updateNativeTooltip(remove: true),
      child: widget.child,
    );
  }
}
