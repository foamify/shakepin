import 'dart:io';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop/custom_drag_gesture.dart';
import 'package:shakepin/app/main_drop/drop_section.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/file_image_widget.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:path/path.dart' as path;

class DroppedItem extends StatefulWidget {
  const DroppedItem({
    super.key,
    required this.path,
    required this.onDragStart,
    required this.onToggleSelection,
    required this.onRemove,
    required this.isSelected,
    required this.isHoveredItem,
    required this.onEnter,
    required this.onExit,
    required this.displayMode,
  });

  final String path;
  final VoidCallback onDragStart;
  final VoidCallback onToggleSelection;
  final VoidCallback onRemove;
  final bool isSelected;
  final bool isHoveredItem;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final DisplayMode displayMode;

  @override
  State<DroppedItem> createState() => _DroppedItemState();
}

class _DroppedItemState extends State<DroppedItem> {
  @override
  void initState() {
    appMode.addListener(appModeListener);
    super.initState();
  }

  @override
  void dispose() {
    appMode.removeListener(appModeListener);
    super.dispose();
  }

  void appModeListener() {
    setState(() {});
  }

  bool get isDisabled => !appMode().isFileCompatible(widget.path);

  @override
  Widget build(BuildContext context) {
    menuProvider(request) => Menu(
          children: [
            MenuAction(
              title: 'Show in Finder',
              callback: () async {
                try {
                  final result = await Process.run('open', ['-R', widget.path]);
                  if (result.exitCode != 0) {
                    throw Exception(result.stderr);
                  }
                } catch (e) {
                  logger.log('Error opening file: $e');
                }
              },
            ),
            MenuAction(
              title: 'Remove',
              callback: () {
                widget.onRemove();
              },
            ),
          ],
        );

    Widget child;
    final icon = isUrl(widget.path)
        ? SizedBox(
            width: 48 + 14,
            height: 48 + 14,
            child: MacosIcon(
              CupertinoIcons.link,
              color: MacosColors.labelColor.resolveFrom(context),
              size: widget.displayMode == DisplayMode.list ? 16 : 48,
            ),
          )
        : FileImageWidget(path: widget.path);

    if (widget.displayMode == DisplayMode.list) {
      final file = File(widget.path);
      final fileName =
          isUrl(widget.path) ? widget.path : path.basename(widget.path);
      final fileSize =
          file.existsSync() ? formatFileSize(file.lengthSync()) : '';

      child = GestureDetector(
        onTapDown: (_) {},
        onTap: widget.onToggleSelection,
        child: AnimatedContainer(
          duration: Durations.short2,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? MacosColors.controlAccentColor
                : Colors.transparent,
          ),
          foregroundDecoration: BoxDecoration(
            color: widget.isHoveredItem
                ? MacosColors.systemGrayColor
                    .resolvedColor(context)
                    .withOpacity(.2)
                : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 16,
                child: icon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fileSize,
                style: TextStyle(
                  fontSize: 12,
                  color: MacosColors.labelColor
                      .resolvedColor(context)
                      .withOpacity(.5),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      child = AnimatedContainer(
        height: 72,
        duration: Durations.short4,
        curve: Curves.fastEaseInToSlowEaseOut,
        // foregroundDecoration: BoxDecoration(
        //   borderRadius: BorderRadius.circular(4),
        //   border: isSelected
        //       ? Border.all(color: MacosColors.controlAccentColor, width: 2)
        //       : null,
        // ),
        child: MacosIconButton(
          onPressed: () {
            widget.onToggleSelection();
          },
          backgroundColor: widget.isSelected
              ? MacosColors.controlAccentColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          hoverColor: widget.isSelected
              ? Color.lerp(MacosColors.controlAccentColor,
                  MacosColors.labelColor.resolvedColor(context), .2)
              : MacosColors.controlColor.resolveFrom(context),
          icon: Stack(
            children: [
              Opacity(
                opacity: isDisabled ? 0.2 : 1,
                child: Column(
                  children: [
                    icon,
                    SizedBox(
                      height: 14,
                      width: 80,
                      child: ExtendedText(
                        isUrl(widget.path)
                            ? widget.path
                            : widget.path.split('/').last,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        overflowWidget: const TextOverflowWidget(
                          position: TextOverflowPosition.middle,
                          align: TextOverflowAlign.center,
                          child: Text('…', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              if (isDisabled)
                Positioned.fill(
                  child: MacosIcon(
                    CupertinoIcons.eye_slash,
                    color: MacosColors.systemRedColor.resolveFrom(context),
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return CustomDragGesture(
      onDragStart: widget.onDragStart,
      child: ContextMenuWidget(
        menuProvider: menuProvider,
        child: MouseRegion(
          onEnter: (event) {
            // dropChannel.showPopover(
            //   path,
            //   edge: PopoverEdge.bottom,
            // );
            widget.onEnter();
          },
          onExit: (_) {
            widget.onExit();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!widget.isHoveredItem) {
                dropChannel.hidePopover();
              }
            });
          },
          child: child,
        ),
      ),
    );
  }
}
