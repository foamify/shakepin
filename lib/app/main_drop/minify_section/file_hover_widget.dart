
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/utils.dart';

class FileHoverWidget extends StatefulWidget {
  const FileHoverWidget({
    super.key,
    required this.icon,
    required this.fileName,
    required this.fileSize,
  });

  final IconData icon;
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
            Icon(widget.icon, size: 16),
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
