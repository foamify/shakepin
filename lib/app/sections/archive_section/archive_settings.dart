import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/widgets/native_dropdown_button.dart';

class ArchiveSettings extends StatefulWidget {
  const ArchiveSettings({super.key});

  @override
  State<ArchiveSettings> createState() => _ArchiveSettingsState();
}

class _ArchiveSettingsState extends State<ArchiveSettings> {
  final progressNotifier = ValueNotifier(-1.0);
  ArchiveFormat selectedFormat = ArchiveFormat.zip;
  int compressionLevel = 6;
  final passwordController = TextEditingController();
  String? customOutputPath;

  @override
  void initState() {
    progressNotifier.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    passwordController.dispose();
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
              Row(
                children: [
                  const Text('Archive format'),
                  const Spacer(),
                  NativeDropdownButton<ArchiveFormat>(
                    items: ArchiveFormat.values.map((format) {
                      return NativeDropdownItem(
                        value: format,
                        label: format.label,
                      );
                    }).toList(),
                    value: selectedFormat,
                    child: Text(selectedFormat.label),
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value ?? ArchiveFormat.zip;
                      });
                    },
                  ),
                ],
              ),
              if (selectedFormat.supportsCompression) ...[
                Divider(
                    color: MacosColors.systemGrayColor.withValues(alpha: .2)),
                Row(
                  children: [
                    const Text('Compression level'),
                    const Spacer(),
                    NativeDropdownButton<int>(
                      items: List.generate(
                        selectedFormat.maxCompressionLevel + 1,
                        (i) => NativeDropdownItem(
                          value: i,
                          label:
                              '$i ${i == 0 ? "(None)" : i == selectedFormat.maxCompressionLevel ? "(Max)" : ""}',
                        ),
                      ),
                      value: compressionLevel,
                      child: Text(compressionLevel.toString()),
                      onChanged: (value) {
                        setState(() {
                          compressionLevel = value ?? 6;
                        });
                      },
                    ),
                  ],
                ),
              ],
              // Temporary disable, not working yet
              // Row(
              //   children: [
              //     const Text('Password: '),
              //     const Spacer(),
              //     SizedBox(
              //       width: 140,
              //       child: MacosTextField(
              //         controller: passwordController,
              //         placeholder: 'Optional password',
              //         obscureText: true,
              //         textAlign: TextAlign.end,
              //       ),
              //     ),
              //   ],
              // ),

              Divider(color: MacosColors.systemGrayColor.withValues(alpha: .2)),
              Row(
                children: [
                  const Text('Output path'),
                  const Spacer(),
                  NativeDropdownButton<String>(
                    items: [
                      const NativeDropdownItem(
                          value: 'source', label: 'Same as source'),
                      if (customOutputPath != null)
                        NativeDropdownItem(
                          value: customOutputPath!,
                          label: customOutputPath!,
                        ),
                      const NativeDropdownItem(
                        value: 'select',
                        label: 'Select output path',
                      ),
                    ],
                    value: customOutputPath ?? 'source',
                    onChanged: (value) async {
                      if (value == 'source') {
                        setState(() => customOutputPath = null);
                      } else if (value == 'select') {
                        final directory = await getDirectoryPath();
                        if (directory != null) {
                          setState(() => customOutputPath = directory);
                        }
                      } else {
                        setState(() => customOutputPath = value);
                      }
                    },
                    child: SizedBox(
                      width: 100,
                      child: Text(
                        customOutputPath ?? 'Same as source',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          child: Column(
            spacing: 8,
            children: [
              if (progressNotifier.value != -1)
                Column(
                  spacing: 8,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ProgressBar(
                        value: progressNotifier(),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 32,
                      child: GlassButton(
                        secondary: true,
                        onTap: () {
                          progressNotifier.value = -1;
                          cli.cancel();
                        },
                        radius: 16,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                )
              else
                ValueListenableBuilder(
                  valueListenable: selectedItems,
                  builder: (context, items, _) {
                    return GlassButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onTap: items.isEmpty
                          ? null
                          : () async {
                              progressNotifier.value = 0;
                              final outputDir =
                                  customOutputPath ?? path.dirname(items.first);
                              await cli.archiveFiles(
                                items.toList(),
                                outputDir,
                                format: selectedFormat,
                                compressionLevel: compressionLevel,
                                password: passwordController.text.isEmpty
                                    ? null
                                    : passwordController.text,
                                onProgress: (progress) {
                                  progressNotifier.value = progress;
                                },
                              );
                              progressNotifier.value = -1;
                            },
                      radius: 16,
                      child: const Text('Archive Files'),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
