import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop/drop_section.dart';
import 'package:shakepin/app/main_drop/minify_section/minify_state.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/widgets/glass_button.dart';

class MiscSettings extends StatefulWidget {
  const MiscSettings({super.key});

  @override
  State<MiscSettings> createState() => _MiscSettingsState();
}

class _MiscSettingsState extends State<MiscSettings> {
  final progressNotifier = ValueNotifier(0.0);

  @override
  Widget build(BuildContext context) {
    return Column(
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
            valueListenable: items,
            builder: (context, items, _) {
              return GlassButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: items.isEmpty
                    ? null
                    : () async {
                        progressNotifier.value = 0;
                        await cli.convertToWav(
                          items.first,
                          onProgress: (progress) {
                            progressNotifier.value = progress;
                          },
                        );
                        progressNotifier.value = -1;
                      },
                radius: 10,
                child: const Text('Extract Audio'),
              );
            }),
      ],
    );
  }
}
