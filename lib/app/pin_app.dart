import 'dart:math';
import 'dart:typed_data';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_hover_widget.dart';
import 'package:shakepin/utils/drop_channel.dart';

class PinApp extends StatefulWidget {
  const PinApp({super.key});

  @override
  State<PinApp> createState() => _PinAppState();
}

class _PinAppState extends State<PinApp> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    dropChannel.setMinimumSize(AppSizes.pin);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DropHoverWidget(
            onDragPerform: (paths) {
              setState(() {
                items.value = items().union(paths.toSet());
              });
            },
          ),
        ),
        Positioned(
          top: 40,
          bottom: 24,
          child: LayoutBuilder(builder: (context, constraints) {
            final height = constraints.maxHeight;
            final paths = items().toList();
            const itemHeight = 64;
            final maxVisibleItems = (height / itemHeight).floor();
            return SizedBox(
              width: MediaQuery.sizeOf(context).width,
              child: MacosScrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  itemCount: (paths.length / maxVisibleItems).ceil(),
                  itemBuilder: (context, row) {
                    final colItems = paths.sublist(
                        row * maxVisibleItems, min((row + 1) * maxVisibleItems, paths.length));
                    return Column(
                      children: List.generate(colItems.length, (col) {
                        return FileImageWidget(path: colItems[col]);
                      }),
                    );
                  },
                  scrollDirection: Axis.horizontal,
                ),
              ),
            );
          }),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Row(
            children: [
              MacosIconButton(
                padding: const EdgeInsets.all(4),
                onPressed: () async {
                  items.value = {};
                  isMinifyApp.value = false;
                },
                backgroundColor:
                    CupertinoColors.label.resolveFrom(context).withOpacity(.5),
                hoverColor:
                    CupertinoColors.label.resolveFrom(context).withOpacity(.9),
                pressedOpacity: .6,
                icon: Icon(
                  FluentIcons.dismiss_24_filled,
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              MacosIconButton(
                padding: const EdgeInsets.all(4),
                onPressed: () async {
                  items.value = {};
                  isMinifyApp.value = false;
                },
                backgroundColor:
                    CupertinoColors.label.resolveFrom(context).withOpacity(.5),
                hoverColor:
                    CupertinoColors.label.resolveFrom(context).withOpacity(.9),
                pressedOpacity: .6,
                icon: Icon(
                  FluentIcons.arrow_minimize_24_regular,
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
        width: 48,
        height: 48,
        child: Center(child: ProgressCircle()),
      );
    }

    return Image.memory(
      _iconData!,
      width: 48,
      height: 48,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return const ProgressCircle();
      },
    );
  }
}
