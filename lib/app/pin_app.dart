import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:extended_text/extended_text.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_hover_widget.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:flutter/material.dart' show Colors, Durations;
import 'package:super_context_menu/super_context_menu.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class PinApp extends StatefulWidget {
  const PinApp({super.key});

  @override
  State<PinApp> createState() => _PinAppState();
}

class _PinAppState extends State<PinApp> with DragDropListener {
  final _scrollController = ScrollController();
  Set<String> selectedItems = {};
  String? draggedItem;

  @override
  void initState() {
    dropChannel.setMinimumSize(AppSizes.pin);
    dropChannel.addListener(this);
    super.initState();
  }

  void _toggleAllSelection(bool? value) {
    setState(() {
      if (value == true) {
        selectedItems = Set.from(items());
      } else {
        selectedItems.clear();
      }
    });
  }

  @override
  void onDragSessionEnded(DropOperation operation) {
    // print('onDragSessionEnded $operation');
    switch (operation) {
      case DropOperation.move:
        setState(() {
          if (draggedItem != null) {
            items.remove(draggedItem!);
            draggedItem = null;
          } else {
            items.value = items().union(selectedItems.toSet());
            selectedItems.clear();
          }
        });
      default:
        break;
    }
    super.onDragSessionEnded(operation);
  }

  @override
  void dispose() {
    dropChannel.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths = items().toList();

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
            const itemHeight = 86.0;
            final maxVisibleItems = (height / itemHeight).floor();
            var itemCount = (paths.length / maxVisibleItems).ceil();
            if (itemCount.isNaN || itemCount.isInfinite) {
              itemCount = 0;
            }
            return SizedBox(
              width: MediaQuery.sizeOf(context).width,
              child: MacosScrollbar(
                controller: _scrollController,
                child: SuperListView.builder(
                  controller: _scrollController,
                  itemCount: itemCount,
                  itemBuilder: (context, row) {
                    final colItems = paths.sublist(row * maxVisibleItems,
                        min((row + 1) * maxVisibleItems, paths.length));
                    return Column(
                      children: List.generate(colItems.length, (col) {
                        final path = colItems[col];
                        final isSelected = selectedItems.contains(path);
                        return SizedBox(
                          width: 86,
                          height: itemHeight,
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: ContextMenuWidget(
                              menuProvider: (request) => Menu(children: [
                                MenuAction(
                                  title: 'Show in Finder',
                                  callback: () {
                                    Process.run('open', ['-R', path]);
                                  },
                                ),
                                MenuAction(
                                  title: 'Remove',
                                  callback: () {
                                    setState(() {
                                      items.remove(path);
                                    });
                                  },
                                ),
                              ]),
                              child: RawGestureDetector(
                                gestures: {
                                  VerticalDragGestureRecognizer:
                                      GestureRecognizerFactoryWithHandlers<
                                          VerticalDragGestureRecognizer>(
                                    () => VerticalDragGestureRecognizer(
                                        supportedDevices: {
                                          PointerDeviceKind.touch,
                                          PointerDeviceKind.mouse,
                                        }),
                                    (VerticalDragGestureRecognizer instance) {
                                      instance.onStart = (details) {
                                        if (!selectedItems.contains(path)) {
                                          draggedItem = path;
                                          dropChannel
                                              .performDragSession([path]);
                                        } else {
                                          dropChannel.performDragSession(
                                              selectedItems.toList());
                                        }
                                      };
                                    },
                                  ),
                                  HorizontalDragGestureRecognizer:
                                      GestureRecognizerFactoryWithHandlers<
                                          HorizontalDragGestureRecognizer>(
                                    () => HorizontalDragGestureRecognizer(
                                        supportedDevices: {
                                          PointerDeviceKind.touch,
                                          PointerDeviceKind.mouse,
                                        }),
                                    (HorizontalDragGestureRecognizer instance) {
                                      instance.onStart = (details) {
                                        if (!selectedItems.contains(path)) {
                                          draggedItem = path;
                                          dropChannel
                                              .performDragSession([path]);
                                        } else {
                                          dropChannel.performDragSession(
                                              selectedItems.toList());
                                        }
                                      };
                                    },
                                  ),
                                },
                                child: MacosIconButton(
                                  onPressed: () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedItems.remove(path);
                                      } else {
                                        selectedItems.add(path);
                                      }
                                    });
                                  },
                                  icon: SizedBox(
                                    height: itemHeight,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: FileImageWidget(
                                            key: Key(path),
                                            path: path,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 14,
                                          width: 86,
                                          child: ExtendedText(
                                            path.split('/').last,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors.label
                                                  .resolveFrom(context),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            overflowWidget: TextOverflowWidget(
                                              position:
                                                  TextOverflowPosition.middle,
                                              align: TextOverflowAlign.center,
                                              child: Transform.translate(
                                                offset: const Offset(0, -1.5),
                                                child: const Text('\u2026'),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  backgroundColor: isSelected
                                      ? CupertinoColors.systemBlue
                                          .resolveFrom(context)
                                      : Colors.transparent,
                                  hoverColor: isSelected
                                      ? CupertinoColors.systemBlue
                                          .resolveFrom(context)
                                          .withOpacity(0.7)
                                      : CupertinoColors.systemGrey
                                          .resolveFrom(context)
                                          .withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        );
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
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 150,
              child: Row(
                children: [
                  MacosCheckbox(
                    value: selectedItems.length == paths.length
                        ? true
                        : selectedItems.isEmpty
                            ? false
                            : null,
                    onChanged: _toggleAllSelection,
                  ),
                  const Spacer(),
                  AnimatedSize(
                    duration: Durations.medium2,
                    curve: Curves.easeOutBack,
                    child: Text(
                      selectedItems.isEmpty
                          ? '${paths.length} items'
                          : '${selectedItems.length} / ${paths.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
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
                  dropChannel.setFrame(
                      Rect.fromCenter(
                        center: await dropChannel.center() +
                            Offset(0, AppSizes.pin.height / 2),
                        width: AppSizes.pin.width,
                        height: 1,
                      ),
                      animate: true);
                  await Future.delayed(Durations.short4);
                  dropChannel.setVisible(false);
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
