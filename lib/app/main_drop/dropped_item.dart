import 'dart:io';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/file_image_widget.dart';
import 'package:super_context_menu/super_context_menu.dart';

class DroppedItem extends StatelessWidget {
  const DroppedItem({
    super.key,
    required this.path,
    required this.onToggleSelection,
    required this.onRemove,
    required this.isSelected,
    required this.isHoveredItem,
    required this.onEnter,
    required this.onExit,
  });

  final String path;
  final VoidCallback onToggleSelection;
  final VoidCallback onRemove;
  final bool isSelected;
  final bool isHoveredItem;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return ContextMenuWidget(
      menuProvider: (request) => Menu(children: [
        MenuAction(
          title: 'Show in Finder',
          callback: () async {
            try {
              final result = await Process.run('open', ['-R', path]);
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
            onRemove();
          },
        ),
      ]),
      child: MouseRegion(
        onEnter: (event) {
          // dropChannel.showPopover(
          //   path,
          //   edge: PopoverEdge.bottom,
          // );
          onEnter();
        },
        onExit: (_) {
          onExit();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isHoveredItem) {
              dropChannel.hidePopover();
            }
          });
        },
        child: AnimatedContainer(
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
              onToggleSelection();
            },
            backgroundColor: isSelected
                ? MacosColors.controlAccentColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            hoverColor: isSelected
                ? Color.lerp(MacosColors.controlAccentColor,
                    MacosColors.labelColor.resolvedColor(context), .2)
                : MacosColors.controlColor.resolveFrom(context),
            icon: Column(
              children: [
                FileImageWidget(path: path),
                SizedBox(
                  height: 14,
                  width: 80,
                  child: ExtendedText(
                    path.split('/').last,
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
        ),
      ),
    );
  }
}
