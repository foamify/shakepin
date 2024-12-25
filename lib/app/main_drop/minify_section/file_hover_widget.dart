import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/utils.dart';

class FileHoverWidget extends StatefulWidget {
  const FileHoverWidget({
    super.key,
    this.icon,
    this.child,
    required this.fileName,
    required this.fileSize,
  }) : assert(
          (icon == null) != (child == null),
          'Exactly one of icon or child must be provided',
        );

  final IconData? icon;
  final Widget? child;
  final String fileName;
  final String fileSize;

  @override
  State<FileHoverWidget> createState() => _FileHoverWidgetState();
}

class _FileHoverWidgetState extends State<FileHoverWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: Durations.short2,
        color: _isHovered
            ? MacosColors.systemGrayColor.resolvedColor(context).withOpacity(.2)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            if (widget.icon != null) Icon(widget.icon, size: 16),
            if (widget.child != null) widget.child!,
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.fileName,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.fileSize,
              style: TextStyle(
                fontSize: 12,
                color: MacosColors.systemGrayColor.resolvedColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
