import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop/custom_drag_gesture.dart';
import 'package:shakepin/app/main_drop/dropped_item.dart';
import 'package:shakepin/app/main_drop/minify_section/file_hover_widget.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_target.dart';
import 'package:shakepin/widgets/file_image_widget.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:path/path.dart' as path;

class DropSection extends StatefulWidget {
  const DropSection({super.key});

  @override
  State<DropSection> createState() => _DropSectionState();
}

class _DropSectionState extends State<DropSection> with DragDropListener {
  bool _isDraggingItemIn = false;
  bool _isHoveredItem = false;
  Set<String> _selectedItems = {};
  var _displayMode = DisplayMode.grid;
  String? draggedItem;

  @override
  void initState() {
    dropChannel.addListener(this);
    super.initState();
  }

  void _shareSelectedFiles() async {
    final filesToShare = _selectedItems.isNotEmpty ? _selectedItems : items();
    final xFiles = filesToShare.map((path) => XFile(path)).toList();
    try {
      await dropChannel.shareXFiles(xFiles);
    } catch (e) {
      logger.log('Error sharing files: $e');
    }
  }

  @override
  void onDragSessionEnded(DropOperation operation) {
    // logger.log('onDragSessionEnded $operation');
    switch (operation) {
      case DropOperation.move:
        setState(() {
          if (draggedItem != null) {
            logger.log('Removing dragged item: $draggedItem');
            _selectedItems.remove(draggedItem!);
            items.remove(draggedItem!);
            draggedItem = null;
          } else {
            logger.log('Moving selected items: ${_selectedItems.length}');
            items.value = items().difference(_selectedItems);
            _selectedItems.clear();
          }
        });
        logger.log('Items after move: ${items().length}');
      default:
        break;
    }
    super.onDragSessionEnded(operation);
  }

  @override
  Widget build(BuildContext context) {
    const maxRowItemLength = 3;

    final containsVideoOnly = items().containsVideo && !items().containsImage;
    final containsImageOnly = items().containsImage && !items().containsVideo;
    final containsBoth = items().containsVideo && items().containsImage;

    return DropTarget(
      label: 'main-drop-app',
      onDragEnter: (details) {
        setState(() {
          _isDraggingItemIn = true;
        });
      },
      onDragExited: () {
        setState(() {
          _isDraggingItemIn = false;
        });
      },
      onDragConclude: () {
        dropChannel.hidePopover();
        setState(() {
          _isDraggingItemIn = false;
        });
      },
      onDragPerform: (paths) async {
        items.value = items().union(paths.toSet());
      },
      child: SizedBox(
        // width: AppSizes.main.height - 8,
        width: MediaQuery.sizeOf(context).width - 64,
        // width: max(
        //   AppSizes.main.width,
        //   MediaQuery.sizeOf(context).width - 16,
        // ),
        height: switch (appMode()) {
          // AppMode.minify when containsVideoOnly => 300,
          // AppMode.minify when containsImageOnly => 300,
          // AppMode.minify when containsBoth => 218,
          AppMode.minify => null,
          _ => MediaQuery.sizeOf(context).height - 16,
        },
        child: AnimatedContainer(
          duration: Durations.long2,
          curve: Curves.fastEaseInToSlowEaseOut,
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              color: _isDraggingItemIn
                  ? MacosColors.controlAccentColor
                  : items().isNotEmpty
                      ? MacosColors.controlColor.resolvedColor(context)
                      : MacosColors.transparent,
              width: _isDraggingItemIn ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: _isDraggingItemIn
                ? MacosColors.controlAccentColor.withOpacity(0.1)
                : items().isNotEmpty
                    ? MacosColors.controlColor
                        .resolvedColor(context)
                        .withOpacity(.05)
                    : MacosColors.controlColor
                        .resolvedColor(context)
                        .withOpacity(.1),
          ),
          child: ListenableBuilder(
              listenable: items,
              builder: (context, child) {
                return Column(
                  children: [
                    SizedBox(
                      height: 24,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                spacing: 4,
                                children: [
                                  SizedBox.square(
                                    dimension: 16,
                                    child: GlassButton(
                                      secondary: true,
                                      padding: EdgeInsets.zero,
                                      radius: 3,
                                      onTap: () {
                                        setState(() {
                                          _selectedItems.clear();
                                        });
                                        items.clear();
                                        resetFrameAndHide();
                                      },
                                      child: MacosIcon(
                                        FluentIcons.dismiss_16_regular,
                                        color: MacosColors.labelColor
                                            .resolvedColor(context),
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox.square(
                                    dimension: 16,
                                    child: GlassButton(
                                      secondary: true,
                                      padding: EdgeInsets.zero,
                                      radius: 3,
                                      onTap: () {
                                        resetFrameAndHide();
                                      },
                                      child: MacosIcon(
                                        FluentIcons.arrow_minimize_16_regular,
                                        color: MacosColors.labelColor
                                            .resolvedColor(context),
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${items().length} Files',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Row(
                                spacing: 4,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  MacosCheckbox(
                                    value:
                                        _selectedItems.length == items().length
                                            ? true
                                            : _selectedItems.isEmpty
                                                ? false
                                                : null,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedItems = Set.from(items());
                                        } else {
                                          _selectedItems.clear();
                                        }
                                      });
                                    },
                                  ),
                                  SizedBox.square(
                                    dimension: 16,
                                    child: GlassButton(
                                      secondary: true,
                                      padding: EdgeInsets.zero,
                                      radius: 3,
                                      onTap: _shareSelectedFiles,
                                      child: MacosIcon(
                                        FluentIcons.share_16_regular,
                                        color: MacosColors.labelColor
                                            .resolvedColor(context),
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox.square(
                                    dimension: 16,
                                    child: GlassButton(
                                      secondary: true,
                                      onTap: () {
                                        setState(() {
                                          _displayMode =
                                              _displayMode == DisplayMode.grid
                                                  ? DisplayMode.list
                                                  : DisplayMode.grid;
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      radius: 3,
                                      child: MacosIcon(
                                        _displayMode == DisplayMode.grid
                                            ? FluentIcons
                                                .text_bullet_list_ltr_16_regular
                                            : FluentIcons.grid_16_regular,
                                        color: MacosColors.labelColor
                                            .resolvedColor(context),
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: MacosColors.systemGrayColor
                          .resolvedColor(context)
                          .withOpacity(.2),
                    ),
                    if (items().isNotEmpty)
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: Durations.medium2,
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          child: switch (_displayMode) {
                            DisplayMode.list => SuperListView.separated(
                                itemCount: items().length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                  indent: 12,
                                  endIndent: 12,
                                  height: 1,
                                  color: MacosColors.gridColor,
                                ),
                                itemBuilder: (context, index) {
                                  final filePath = items().elementAt(index);
                                  final file = File(filePath);
                                  final fileName = path.basename(filePath);
                                  final fileSize = file.existsSync()
                                      ? formatFileSize(file.lengthSync())
                                      : '';
                                  // final isImage = isImageFile(fileName);
                                  // final isVideo = isVideoFile(fileName);
                                  // final icon = isImage
                                  //     ? FluentIcons.image_24_regular
                                  //     : isVideo
                                  //         ? FluentIcons.video_24_regular
                                  //         : FluentIcons.document_24_regular;
                                  return CustomDragGesture(
                                    onDragStart: () {
                                      if (!_selectedItems.contains(filePath)) {
                                        draggedItem = filePath;
                                        dropChannel
                                            .performDragSession([filePath]);
                                      } else {
                                        dropChannel.performDragSession(
                                            _selectedItems.toList());
                                      }
                                    },
                                    child: ContextMenuWidget(
                                      menuProvider: (request) => Menu(
                                        children: [
                                          MenuAction(
                                            callback: () {
                                              Process.run(
                                                  'open', ['-R', filePath]);
                                            },
                                            title: 'Show in Finder',
                                          ),
                                          if (_selectedItems.contains(filePath))
                                            MenuAction(
                                              callback: () {
                                                setState(() {
                                                  _selectedItems
                                                      .remove(filePath);
                                                });
                                              },
                                              title: 'Deselect',
                                            ),
                                          if (!_selectedItems
                                              .contains(filePath))
                                            MenuAction(
                                              callback: () {
                                                setState(() {
                                                  _selectedItems.add(filePath);
                                                });
                                              },
                                              title: 'Select',
                                            ),
                                          MenuAction(
                                            callback: () {
                                              items.remove(filePath);
                                              _selectedItems.remove(filePath);
                                            },
                                            title: 'Remove',
                                          ),
                                        ],
                                      ),
                                      child: FileHoverWidget(
                                        fileName: fileName,
                                        fileSize: fileSize,
                                        onTap: () {
                                          setState(() {
                                            if (_selectedItems
                                                .contains(filePath)) {
                                              _selectedItems.remove(filePath);
                                            } else {
                                              _selectedItems.add(filePath);
                                            }
                                          });
                                        },
                                        selected:
                                            _selectedItems.contains(filePath),
                                        // icon: icon,
                                        child: SizedBox.square(
                                          dimension: 16,
                                          child: FileImageWidget(
                                            path: filePath,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            _ => SuperListView.builder(
                                padding: const EdgeInsets.all(4),
                                itemCount:
                                    (items().length / maxRowItemLength).ceil(),
                                itemBuilder: (context, rowIndex) {
                                  final startIndex =
                                      rowIndex * maxRowItemLength;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      spacing: 4,
                                      children: List.generate(maxRowItemLength,
                                          (index) {
                                        final itemIndex = startIndex + index;

                                        if (itemIndex < items().length) {
                                          final path =
                                              items().elementAt(itemIndex);
                                          final isSelected =
                                              _selectedItems.contains(path);
                                          return Expanded(
                                            child: CustomDragGesture(
                                              onDragStart: () {
                                                if (!_selectedItems
                                                    .contains(path)) {
                                                  draggedItem = path;
                                                  dropChannel
                                                      .performDragSession(
                                                          [path]);
                                                } else {
                                                  dropChannel
                                                      .performDragSession(
                                                          _selectedItems
                                                              .toList());
                                                }
                                              },
                                              child: DroppedItem(
                                                onEnter: () {
                                                  setState(() {
                                                    _isHoveredItem = true;
                                                  });
                                                },
                                                onExit: () {
                                                  setState(() {
                                                    _isHoveredItem = false;
                                                  });
                                                },
                                                onRemove: () {
                                                  items.remove(path);
                                                  _selectedItems.remove(path);
                                                },
                                                path: path,
                                                isSelected: isSelected,
                                                onToggleSelection: () {
                                                  setState(() {
                                                    if (isSelected) {
                                                      _selectedItems
                                                          .remove(path);
                                                    } else {
                                                      _selectedItems.add(path);
                                                    }
                                                  });
                                                },
                                                isHoveredItem: _isHoveredItem,
                                              ),
                                            ),
                                          );
                                        } else {
                                          return const Expanded(
                                              child: SizedBox.shrink());
                                        }
                                      }),
                                    ),
                                  );
                                },
                              )
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0).copyWith(top: 0),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: Durations.long2,
                              curve: Curves.fastEaseInToSlowEaseOut,
                              style: TextStyle(
                                color: _isDraggingItemIn
                                    ? MacosColors.controlAccentColor
                                    : MacosColors.labelColor
                                        .resolvedColor(context),
                              ),
                              child: const Text('Drop files here'),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),
        ),
      ),
    );
  }
}

enum DisplayMode {
  grid,
  list,
}
