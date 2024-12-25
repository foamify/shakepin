import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/drop_channel.dart';

class FileImageWidget extends StatefulWidget {
  const FileImageWidget({super.key, required this.path});

  final String path;

  @override
  State<FileImageWidget> createState() => _FileImageWidgetState();
}

class _FileImageWidgetState extends State<FileImageWidget> {
  Uint8List? _iconData;

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  Future<void> _loadIcon() async {
    try {
      final iconData = await dropChannel.getFileIcon(widget.path);
      if (mounted) {
        setState(() {
          _iconData = iconData;
        });
      }
    } catch (e) {
      print('Error loading file icon: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_iconData == null) {
      return const SizedBox(
        width: 48 + 14,
        height: 48 + 14,
        child: Center(child: ProgressCircle()),
      );
    }

    return Image.memory(
      _iconData!,
      width: 48 + 14,
      height: 48 + 14,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return const ProgressCircle();
      },
    );
  }
}
