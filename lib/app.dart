import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_haptic_feedback/macos_haptic_feedback.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/state.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DropApp extends StatefulWidget {
  const DropApp({super.key});

  @override
  State<DropApp> createState() => _DropAppState();
}

class _DropAppState extends State<DropApp> with TrayListener {
  var dragItemKeys = <GlobalKey<DragItemWidgetState>>[];
  var dragWidgetKeys = <GlobalKey>[];
  var images = <String, Uint8List>{};
  var selectedItems = <String>[];
  var preventRender = false;
  final haptic = MacosHapticFeedback();
  var draggingLocal = false;

  @override
  void initState() {
    super.initState();
    // windowManager.setTitleBarStyle(TitleBarStyle.hidden,
    //     windowButtonVisibility: false);
    trayManager.addListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'ShakePin',
      home: PlatformMenuBar(
        menus: const [],
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedContainer(
            duration: Durations.medium2,
            decoration: BoxDecoration(
              border: Border.all(
                  color: hover && !draggingLocal
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemBlue.withOpacity(0),
                  width: 4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                if (items.isEmpty)
                  const Positioned(
                      right: 0,
                      left: 0,
                      top: 86,
                      child: Center(
                        child: Text(
                          'Drop files here',
                          style: TextStyle(color: CupertinoColors.systemGrey6),
                          textAlign: TextAlign.center,
                        ),
                      )),
                ...items.indexed.map(
                  (e) => Positioned(
                    top: 0,
                    child: DragItemWidget(
                      key: dragItemKeys[e.$1],
                      dragBuilder: (context, child) {
                        if (preventRender) {
                          return const SizedBox(width: 1, height: 1);
                        }
                        return SizedBox(
                          // width: 1,
                          // height: 1,
                          width: 100,
                          height: 100,
                          child: Image.memory(images[
                              e.$2.path.split('.').last == "app"
                                  ? e.$2.path
                                  : e.$2.path.split('.').last]!),
                        );
                      },
                      dragItemProvider: (dragItemRequest) {
                        final item = DragItem();
                        item.add(Formats.fileUri(Uri.file(e.$2.path)));
                        return item;
                      },
                      allowedOperations: () => [
                        DropOperation.move,
                        DropOperation.copy,
                        DropOperation.link,
                        DropOperation.forbidden,
                        DropOperation.userCancelled,
                        DropOperation.none,
                      ],
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DragToMoveArea(
                    child: SizedBox.shrink(),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: DropTarget(
                      onDragEntered: (data) {
                        haptic.levelChange();
                        setState(() {
                          hover = true;
                        });
                        // print('entered');
                      },
                      onDragExited: (data) {
                        setState(() {
                          hover = false;
                        });
                      },
                      onDragDone: (data) async {
                        if (draggingLocal) return;
                        setState(() {
                          selectedItems.clear();
                          loadingImages = true;
                        });
                        windowManager.clearPasteboard();
                        images.clear();
                        // final formats = <String>{}; TODO: optimize getting file icon images
                        items.addAll(data.files.where((e) {
                          for (var i = 0; i < items.length; i++) {
                            if (items.elementAt(i).path == e.path) {
                              return false;
                            }
                          }
                          return true;
                        }));
                        final newImages = <String, Uint8List>{};
                        final paths = items.map((e) => e.path).toSet();
                        await Future.wait(paths.map((path) async {
                          if (path.split('.').last != "app" &&
                              images[path.split('.').last] != null) {
                            newImages[path.split('.').last] =
                                images[path.split('.').last]!;
                          } else {
                            final image =
                                await windowManager.getIconImage(path);
                            newImages[path.split('.').last == "app"
                                ? path
                                : path.split('.').last] = image!;
                          }
                        }));
                        setState(() {
                          images = newImages;
                          dragItemKeys = List.generate(items.length,
                              (index) => GlobalKey<DragItemWidgetState>());
                          dragWidgetKeys = List.generate(
                              items.length, (index) => GlobalKey());
                          loadingImages = false;
                        });
                      },
                      child: loadingImages
                          ? const Center(child: ProgressCircle())
                          : LayoutBuilder(builder: (context, constraints) {
                              return Container(
                                color: Colors.transparent,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: Center(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(top: 36),
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      height: constraints.maxHeight,
                                      child: Wrap(
                                        runSpacing: 4,
                                        direction: Axis.vertical,
                                        children: [
                                          ...items.indexed.map(
                                            (e) {
                                              final index = e.$1;
                                              final item = e.$2;
                                              return SizedBox(
                                                width: 80,
                                                height: 100,
                                                child: MacosIconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      if (selectedItems
                                                          .contains(
                                                              item.path)) {
                                                        selectedItems
                                                            .remove(item.path);
                                                      } else {
                                                        selectedItems
                                                            .add(item.path);
                                                      }
                                                    });
                                                  },
                                                  hoverColor: selectedItems
                                                          .contains(item.path)
                                                      ? MacosColors
                                                          .systemBlueColor
                                                          .withOpacity(.8)
                                                      : null,
                                                  backgroundColor: selectedItems
                                                          .contains(item.path)
                                                      ? MacosColors
                                                          .systemBlueColor
                                                      : null,
                                                  icon: MacosTooltip(
                                                    message: item.path
                                                        .split('/')
                                                        .last,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        AnimatedRotation(
                                                          duration:
                                                              Durations.long3,
                                                          turns: 0,
                                                          // turns: ((items.length - e.$1 - 1) % 5) /
                                                          //     items.length /
                                                          //     180 *
                                                          //     12 *
                                                          //     ((items.length - e.$1) % 5),
                                                          child:
                                                              DraggableWidget(
                                                            onDragConfiguration:
                                                                (
                                                              DragConfiguration
                                                                  configuration,
                                                              DragSession
                                                                  session,
                                                            ) async {
                                                              if (session
                                                                  .dragStarted) {
                                                                final data =
                                                                    (await session
                                                                            .getLocalData()) !=
                                                                        null;
                                                                setState(() {
                                                                  draggingLocal =
                                                                      true &&
                                                                          data;
                                                                });
                                                              }
                                                              session.dragging
                                                                  .addListener(
                                                                      () async {
                                                                if (session
                                                                    .dragging
                                                                    .value) {
                                                                  final data =
                                                                      (await session
                                                                              .getLocalData()) !=
                                                                          null;
                                                                  setState(() {
                                                                    draggingLocal =
                                                                        true &&
                                                                            data;
                                                                  });
                                                                } else {
                                                                  setState(() {
                                                                    draggingLocal =
                                                                        false;
                                                                  });
                                                                }
                                                              });
                                                              session
                                                                  .dragCompleted
                                                                  .addListener(
                                                                      () async {
                                                                // print('dragcomplete');
                                                                if (session
                                                                        .dragCompleted
                                                                        .value ==
                                                                    DropOperation
                                                                        .move) {
                                                                  setState(() {
                                                                    items.remove(
                                                                        e.$2);
                                                                    dragItemKeys
                                                                        .removeAt(
                                                                            e.$1);
                                                                    dragWidgetKeys
                                                                        .removeAt(
                                                                            e.$1);
                                                                    selectedItems
                                                                        .remove(e
                                                                            .$2
                                                                            .path);
                                                                  });
                                                                }
                                                              });
                                                              return configuration;
                                                            },
                                                            dragItemsProvider:
                                                                (context) => [
                                                              dragItemKeys
                                                                  .elementAt(
                                                                      e.$1)
                                                                  .currentState!
                                                            ],
                                                            child: SizedBox(
                                                              key:
                                                                  dragWidgetKeys[
                                                                      index],
                                                              height: 80,
                                                              child: switch (
                                                                  item
                                                                      .name
                                                                      .split(
                                                                          '.')
                                                                      .last) {
                                                                // 'png' => SizedBox(
                                                                //     width: 100,
                                                                //     height: 100,
                                                                //     child: Image.file(
                                                                //       File(e.$2.path),
                                                                //       width: 100,
                                                                //       height: 100,
                                                                //       filterQuality:
                                                                //           FilterQuality.medium,
                                                                //       fit: BoxFit.cover,
                                                                //     ),
                                                                //   ),
                                                                _
                                                                    when images[e.$2.path.split('.').last ==
                                                                                "app"
                                                                            ? e.$2.path
                                                                            : e.$2.path.split('.').last] !=
                                                                        null =>
                                                                  Image.memory(
                                                                    images[e.$2.path.split('.').last ==
                                                                            "app"
                                                                        ? e.$2
                                                                            .path
                                                                        : e.$2
                                                                            .path
                                                                            .split('.')
                                                                            .last]!,
                                                                  ),
                                                                _ =>
                                                                  const ProgressCircle()
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 80,
                                                          child: Text(
                                                            e.$2.path
                                                                .split('/')
                                                                .last,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              color: CupertinoColors
                                                                  .systemGrey6,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                    ),
                  ),
                ),
                if (items.length > 1)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MacosCheckbox(
                          activeColor: CupertinoColors.systemBlue,
                          value: selectedItems.length == items.length
                              ? true
                              : selectedItems.isNotEmpty
                                  ? null
                                  : false,
                          onChanged: (value) {
                            if (value == true) {
                              setState(() {
                                selectedItems.clear();
                                for (var e in items) {
                                  selectedItems.add(e.path);
                                }
                              });
                              return;
                            }
                            setState(() {
                              selectedItems.clear();
                            });
                          },
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Listener(
                          onPointerMove: (_) {
                            setState(() {
                              preventRender = true;
                            });
                          },
                          child: DraggableWidget(
                            onDragConfiguration:
                                (configuration, session) async {
                              if (session.dragStarted) {
                                final data =
                                    (await session.getLocalData()) != null;
                                setState(() {
                                  draggingLocal = true && data;
                                  preventRender = true;
                                });
                              }
                              session.dragging.addListener(() async {
                                final data =
                                    (await session.getLocalData()) != null;
                                if (session.dragging.value) {
                                  setState(() {
                                    draggingLocal = true && data;
                                    preventRender = true;
                                  });
                                } else {
                                  setState(() {
                                    draggingLocal = false;
                                    preventRender = false;
                                  });
                                }
                              });
                              session.dragCompleted.addListener(() {
                                if (session.dragCompleted.value ==
                                    DropOperation.move) {
                                  setState(() {
                                    draggingLocal = false;
                                    preventRender = false;
                                    items.clear();
                                    dragItemKeys.clear();
                                    dragWidgetKeys.clear();
                                    selectedItems.clear();
                                  });
                                }
                              });
                              return configuration;
                            },
                            dragItemsProvider: (_) => dragItemKeys
                                .whereIndexed((index, element) {
                                  return (selectedItems
                                      .contains(items.elementAt(index).path));
                                })
                                .map((e) => e.currentState!)
                                .toList(),
                            child: PushButton(
                              onPressed: () {},
                              controlSize: ControlSize.regular,
                              child: Row(
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, 1),
                                    child: const SizedBox(
                                      width: 12,
                                      height: 16,
                                      child: MacosIcon(
                                        FluentIcons
                                            .re_order_dots_vertical_24_filled,
                                        color: MacosColors.textColor,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'All ${selectedItems.length} files',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  left: 4,
                  top: 4,
                  child: Row(
                    children: [
                      MacosIconButton(
                        padding: const EdgeInsets.all(0),
                        onPressed: () {
                          setState(() {
                            items.clear();
                            positions.clear();
                          });
                          Future.delayed(const Duration(milliseconds: 50), () {
                            isVisible = false;
                            windowManager.minimize();
                          });
                          // windowManager.setSkipTaskbar(true);
                        },
                        icon: const Icon(
                          FluentIcons.dismiss_square_24_filled,
                          color: CupertinoColors.systemGrey6,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 4),
                      MacosIconButton(
                        padding: const EdgeInsets.all(0),
                        onPressed: () {
                          isVisible = false;
                          windowManager.minimize();
                          // windowManager.setSkipTaskbar(true);
                        },
                        icon: const Icon(
                          FluentIcons.arrow_minimize_28_regular,
                          color: CupertinoColors.systemGrey6,
                          size: 18,
                        ),
                      ),
                    ],
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
