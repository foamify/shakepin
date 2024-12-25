import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop/minify_section/file_hover_widget.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_target.dart';
import 'package:path/path.dart' as path;
import 'package:super_context_menu/super_context_menu.dart';

class MinifyDropSection extends StatefulWidget {
  const MinifyDropSection({super.key});

  @override
  State<MinifyDropSection> createState() => _MinifyDropSectionState();
}

class _MinifyDropSectionState extends State<MinifyDropSection> {
  final isDragging = ValueNotifier<bool>(false);
  final fileScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: items,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropTarget(
                label: 'minify-drop',
                onDragEnter: (position) {
                  isDragging.value = true;
                },
                onDragExited: () {
                  isDragging.value = false;
                },
                onDragPerform: (paths) {
                  isDragging.value = false;
                  items.addAll(paths.where(isSupportedFile).toSet());
                },
                onDragConclude: () {},
                child: AnimatedContainer(
                  duration: Durations.medium2,
                  height: AppSizes.main.height - 24,
                  foregroundDecoration: BoxDecoration(
                    border: isDragging()
                        ? Border.all(
                            color: MacosColors.systemBlueColor,
                            width: 2,
                          )
                        : Border.all(
                            color: MacosColors.systemGrayColor
                                .resolvedColor(context)
                                .withOpacity(.3),
                          ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: items().isEmpty
                      ? Center(
                          child: Text(
                            'Drop files here',
                            style: TextStyle(
                              fontSize: 16,
                              color: MacosColors.systemGrayColor
                                  .resolvedColor(context),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: 24,
                              child: Center(
                                child: Text(
                                  '${items().length} Files',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: MacosColors.systemGrayColor
                                  .resolvedColor(context)
                                  .withOpacity(.2),
                            ),
                            Expanded(
                              child: MacosScrollbar(
                                controller: fileScrollController,
                                child: ListView.separated(
                                  controller: fileScrollController,
                                  itemCount: items().length,
                                  separatorBuilder: (context, index) => Divider(
                                    indent: 12,
                                    endIndent: 12,
                                    height: 1,
                                    color: MacosColors.systemGrayColor
                                        .resolvedColor(context)
                                        .withOpacity(.2),
                                  ),
                                  itemBuilder: (context, index) {
                                    final filePath = items().elementAt(index);
                                    final file = File(filePath);
                                    final fileName = path.basename(filePath);
                                    final fileSize =
                                        formatFileSize(file.lengthSync());
                                    final isImage = isImageFile(fileName);
                                    final icon = isImage
                                        ? FluentIcons.image_24_regular
                                        : FluentIcons.video_24_regular;
                                    return ContextMenuWidget(
                                      menuProvider: (request) => Menu(
                                        children: [
                                          MenuAction(
                                            callback: () {
                                              Process.run(
                                                  'open', ['-R', filePath]);
                                            },
                                            title: 'Show in Finder',
                                          ),
                                          MenuAction(
                                            callback: () {
                                              items.remove(filePath);
                                            },
                                            title: 'Remove',
                                          ),
                                        ],
                                      ),
                                      child: FileHoverWidget(
                                        icon: icon,
                                        selected: false,
                                        fileName: fileName,
                                        fileSize: fileSize,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        });
  }
}
