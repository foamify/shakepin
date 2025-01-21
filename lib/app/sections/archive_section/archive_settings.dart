import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/utils.dart';
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
  void initState() {
    progressNotifier.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MacosColors.systemGrayColor.withOpacity(.2)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(6),
          bottom: Radius.circular(24),
        ),
        color: MacosColors.controlColor.resolvedColor(context).withOpacity(.03),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        spacing: 8,
        children: [
          if (progressNotifier.value != -1)
            SizedBox(
              width: double.infinity,
              child: ProgressBar(
                value: progressNotifier(),
              ),
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
                  radius: 16,
                  child: const Text('Archive Files'),
                );
              }),
        ],
      ),
    );
  }
}
