import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:shakepin/widgets/cli_aware_button.dart';
import 'package:shakepin/widgets/native_dropdown_button.dart';

//TODO: set output path

class MiscSettings extends StatefulWidget {
  const MiscSettings({super.key});

  @override
  State<MiscSettings> createState() => _MiscSettingsState();
}

class _MiscSettingsState extends State<MiscSettings> {
  final progressNotifier = ValueNotifier(-1.0);
  AudioFormat selectedFormat = AudioFormat.wav;
  int selectedSampleRate = 16000;

  static final List<int> sampleRates = [8000, 16000, 22050, 44100, 48000];

  List<String> _getRequiredTools() {
    final tools = <String>{};
    
    switch (appMode()) {
      case AppMode.convertToIco:
        tools.add('imagemagick');
      case AppMode.extractAudio:
        tools.add('ffmpeg');
      case AppMode.downloadVideo:
        tools.add('yt-dlp');
      case AppMode.downloadMedia:
        tools.add('gallery-dl');
      default:
        break;
    }
    
    return tools.toList();
  }

  Future<void> _performMiscOperation() async {
    final items = selectedItems();
    if (items.isEmpty || items.every((e) => !appMode().isFileCompatible(e))) {
      return;
    }
    
    progressNotifier.value = 0;
    try {
      switch (appMode()) {
        case AppMode.convertToIco:
          await cli.convertToIco(items.first);
        case AppMode.extractAudio:
          await cli.extractAudio(
            items.toList(),
            format: selectedFormat,
            sampleRate: selectedSampleRate,
            onProgress: (progress) {
              progressNotifier.value = progress;
            },
          );
        case AppMode.downloadVideo:
          await cli.downloadVideo(
            items.first,
            onProgress: (progress) {
              progressNotifier.value = progress;
            },
          );
        case AppMode.downloadMedia:
          await cli.downloadMedia(
            items.first,
            onProgress: (progress) {
              progressNotifier.value = progress;
            },
          );
        default:
          logger.log('Unsupported app mode: ${appMode()}');
      }
    } catch (e) {
      String operationName = switch (appMode()) {
        AppMode.convertToIco => 'Icon conversion',
        AppMode.extractAudio => 'Audio extraction',
        AppMode.downloadVideo => 'Video download',
        AppMode.downloadMedia => 'Media download',
        _ => 'Operation'
      };
      errorMessages.value = ['$operationName failed: $e'];
    }
    progressNotifier.value = -1;
  }

  @override
  void initState() {
    // Listen for retry triggers
    retryTrigger.addListener(() {
      if (retryTrigger.value == 'misc') {
        retryTrigger.value = null; // Reset trigger
        _performMiscOperation();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    progressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: MacosColors.systemGrayColor.withValues(alpha: .2)),
            borderRadius: BorderRadius.circular(6),
            color: MacosColors.controlColor
                .resolvedColor(context)
                .withValues(alpha: .03),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // Tool selector row
              ValueListenableBuilder<AppMode>(
                valueListenable: appMode,
                builder: (context, appMode, _) {
                  return Row(
                    children: [
                      const Text('Select tool'),
                      const Spacer(),
                      NativeDropdownButton<String>(
                        items: AppMode.values
                            .where((e) => e.label != null)
                            .map((e) {
                          return NativeDropdownItem(
                            value: e.name,
                            label: e.label!,
                          );
                        }).toList(),
                        value: appMode.name,
                        child: Text(appMode.label!),
                        onChanged: (value) {
                          handleModeChanged(AppMode.values
                              .firstWhere((e) => e.name == value));
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: Durations.long1,
          curve: Curves.fastEaseInToSlowEaseOut,
          child: SizedBox(
            width: double.infinity,
            child: ValueListenableBuilder<AppMode>(
              valueListenable: appMode,
              builder: (context, currentMode, _) {
                if (currentMode == AppMode.extractAudio) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: MacosColors.systemGrayColor
                              .withValues(alpha: .2)),
                      borderRadius: BorderRadius.circular(6),
                      color: MacosColors.controlColor
                          .resolvedColor(context)
                          .withValues(alpha: .03),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Output Format'),
                            const Spacer(),
                            NativeDropdownButton<String>(
                              items: AudioFormat.values.map((format) {
                                return NativeDropdownItem(
                                  value: format.extension,
                                  label: format.extension.toUpperCase(),
                                );
                              }).toList(),
                              value: selectedFormat.extension,
                              child:
                                  Text(selectedFormat.extension.toUpperCase()),
                              onChanged: (value) {
                                setState(() {
                                  selectedFormat =
                                      AudioFormat.values.firstWhere(
                                    (format) => format.extension == value,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                        Divider(
                            color: MacosColors.systemGrayColor
                                .withValues(alpha: .2)),
                        Row(
                          children: [
                            const Text('Sample Rate'),
                            const Spacer(),
                            NativeDropdownButton<int>(
                              items: sampleRates.map((rate) {
                                return NativeDropdownItem(
                                  value: rate,
                                  label: '${rate}Hz',
                                );
                              }).toList(),
                              value: selectedSampleRate,
                              child: Text('${selectedSampleRate}Hz'),
                              onChanged: (value) {
                                setState(() {
                                  selectedSampleRate = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        // Warning message
        const Row(
          spacing: 8,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 16,
              color: MacosColors.systemYellowColor,
            ),
            Text(
              'Experimental: These features are in beta\nand may not work as expected.',
              style: TextStyle(
                color: MacosColors.systemYellowColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
        // Process button and progress container
        Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: MacosColors.systemGrayColor.withValues(alpha: .2)),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
              bottom: Radius.circular(24),
            ),
            color: MacosColors.controlColor
                .resolvedColor(context)
                .withValues(alpha: .03),
          ),
          padding: const EdgeInsets.all(8),
          child: ListenableBuilder(
            listenable:
                Listenable.merge([selectedItems, appMode, progressNotifier]),
            builder: (context, _) {
              if (progressNotifier() != -1) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ProgressBar(
                        value: progressNotifier() * 100,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Processing: ${(progressNotifier() * 100).toStringAsFixed(2)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        GlassButton(
                          secondary: true,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          onTap: () {
                            progressNotifier.value = -1;
                            cli.cancel();
                          },
                          radius: 16,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return CliAwareButton(
                requiredTools: _getRequiredTools(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                disabled: selectedItems().isEmpty ||
                        selectedItems()
                            .every((e) => !appMode().isFileCompatible(e)),
                onTap: _performMiscOperation,
                radius: 16,
                child: Text(appMode().label!),
              );
            },
          ),
        ),
      ],
    );
  }
}
