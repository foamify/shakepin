import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:path/path.dart' as path;

class ArchiveSettings extends StatefulWidget {
  const ArchiveSettings({super.key});

  @override
  State<ArchiveSettings> createState() => _ArchiveSettingsState();
}

class _ArchiveSettingsState extends State<ArchiveSettings> {
  final progressNotifier = ValueNotifier(-1.0);

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            return progress == -1
                ? const SizedBox.shrink()
                : ProgressBar(
                    value: progress,
                  );
          },
        ),
        ValueListenableBuilder(
            valueListenable: selectedItems,
            builder: (context, items, _) {
              return GlassButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: items.isEmpty
                    ? null
                    : () async {
                        progressNotifier.value = 0;
                        await cli.archiveFiles(
                          items.toList(),
                          path.dirname(items.first),
                          onProgress: (progress) {
                            progressNotifier.value = progress;
                          },
                        );
                        progressNotifier.value = -1;
                      },
                radius: 8,
                child: const Text('Archive Files'),
              );
            }),
      ],
    );
  }
}
