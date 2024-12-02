import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FilePathDisplay extends StatelessWidget {
  final String label;
  final String filePath;

  const FilePathDisplay({
    super.key,
    required this.label,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            filePath,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class ToolContainer extends StatelessWidget {
  final List<Widget> children;

  const ToolContainer({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.systemGrey.withOpacity(.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
