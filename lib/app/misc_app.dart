import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/misc/tools/tools.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/drop_hover_widget.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart' show Durations;
import 'package:shakepin/widgets/native_dropdown_button.dart';

class MiscApp extends StatefulWidget {
  const MiscApp({super.key});

  @override
  State<MiscApp> createState() => _MiscAppState();
}

class _MiscAppState extends State<MiscApp> {
  final ScrollController _scrollController = ScrollController();
  ToolType _selectedTool = ToolType.convertToIco;

  @override
  void initState() {
    super.initState();
    dropChannel.setMinimumSize(AppSizes.misc);
    _loadPaths();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPaths() async {
    imageMagickPath = prefs.getString('imagemagick_path') ?? '';
    ffmpegPath = prefs.getString('ffmpeg_path') ?? '';

    if (!File(imageMagickPath).existsSync()) {
      imageMagickPath = '';
      prefs.remove('imagemagick_path');
    }
    if (!File(ffmpegPath).existsSync()) {
      ffmpegPath = '';
      prefs.remove('ffmpeg_path');
    }
    setState(() {});
  }

  Widget _buildToolSelector() {
    return Align(
      child: IntrinsicWidth(
        child: NativeDropdownButton<ToolType>(
          value: _selectedTool,
          onChanged: (ToolType? newValue) {
            print('onChanged');
            if (newValue != null) {
              setState(() {
                _selectedTool = newValue;
              });
            }
          },
          items: ToolType.values.map((type) {
            return NativeDropdownItem<ToolType>(
              value: type,
              label: Tools.getToolName(type),
            );
          }).toList(),
          child: Text(Tools.getToolName(_selectedTool)),
        ),
      ),
    );
    // return MacosPopupButton<ToolType>(
    //   value: _selectedTool,
    //   onChanged: (ToolType? newValue) {
    //     if (newValue != null) {
    //       setState(() {
    //         _selectedTool = newValue;
    //       });
    //     }
    //   },
    //   items: ToolType.values.map((type) {
    //     return MacosPopupMenuItem(
    //       value: type,
    //       child: Text(Tools.getToolName(type)),
    //     );
    //   }).toList(),
    // );
  }

  Widget _buildPathSelector() {
    if (_selectedTool == ToolType.convertToIco && imageMagickPath.isEmpty) {
      return _buildImageMagickPathSelector();
    } else if (_selectedTool == ToolType.convertToWav && ffmpegPath.isEmpty) {
      return _buildFFmpegPathSelector();
    }
    return Tools.getToolWidget(_selectedTool);
  }

  Widget _buildImageMagickPathSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ImageMagick Path'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MacosTextField(
                placeholder: 'Enter ImageMagick path',
                controller: TextEditingController(text: imageMagickPath),
                onChanged: (value) => imageMagickPath = value,
              ),
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              child: const Text('Select'),
              onPressed: () async {
                final result = await openFile(acceptedTypeGroups: [
                  const XTypeGroup(
                    label: 'Executable',
                    uniformTypeIdentifiers: ['public.executable'],
                  )
                ]);
                if (result != null) {
                  setState(() {
                    imageMagickPath = result.path;
                  });
                  prefs.setString('imagemagick_path', imageMagickPath);
                }
              },
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              child: const Text('Save'),
              onPressed: () {
                if (imageMagickPath.isNotEmpty) {
                  setState(() {
                    prefs.setString('imagemagick_path', imageMagickPath);
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFFmpegPathSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FFmpeg Path'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MacosTextField(
                placeholder: 'Enter FFmpeg path',
                controller: TextEditingController(text: ffmpegPath),
                onChanged: (value) => ffmpegPath = value,
              ),
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              child: const Text('Select'),
              onPressed: () async {
                final result = await openFile(acceptedTypeGroups: [
                  const XTypeGroup(
                    label: 'Executable',
                    uniformTypeIdentifiers: ['public.executable'],
                  )
                ]);
                if (result != null) {
                  setState(() {
                    ffmpegPath = result.path;
                  });
                  prefs.setString('ffmpeg_path', ffmpegPath);
                }
              },
            ),
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              child: const Text('Save'),
              onPressed: () {
                if (ffmpegPath.isNotEmpty) {
                  setState(() {
                    prefs.setString('ffmpeg_path', ffmpegPath);
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DropHoverWidget(
            onDragPerform: (paths) {
              setState(() {
                items.value = {paths.first};
              });
            },
          ),
        ),
        Positioned.fill(
          child: MacosScrollbar(
            controller: _scrollController,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(
                  top: 40, bottom: 20, left: 20, right: 20),
              children: [
                _buildToolSelector(),
                const SizedBox(height: 20),
                _buildPathSelector(),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Row(
            children: [
              MacosIconButton(
                padding: const EdgeInsets.all(4),
                onPressed: () {
                  items.value = {};
                  setState(() {});
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
                          Offset(0, AppSizes.misc.height / 2),
                      width: AppSizes.misc.width,
                      height: 1,
                    ),
                    animate: true,
                  );
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
