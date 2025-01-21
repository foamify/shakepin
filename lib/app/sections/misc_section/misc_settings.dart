import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:shakepin/widgets/native_dropdown_button.dart';

//TODO: set output path

class MiscSettings extends StatefulWidget {
  const MiscSettings({super.key});

  @override
  State<MiscSettings> createState() => _MiscSettingsState();
}

class _MiscSettingsState extends State<MiscSettings> {
  final progressNotifier = ValueNotifier(-1.0);

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: MacosColors.systemGrayColor.withOpacity(.2)),
            borderRadius: BorderRadius.circular(6),
            color: MacosColors.controlColor
                .resolvedColor(context)
                .withOpacity(.03),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            spacing: 8,
            children: [
              ValueListenableBuilder<AppMode>(
                valueListenable: appMode,
                builder: (context, appMode, _) {
                  return Row(
                    children: [
                      const Text('Select tool '),
                      const Spacer(),
                      IntrinsicWidth(
                        child: NativeDropdownButton<String>(
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
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: MacosColors.systemGrayColor.withOpacity(.2)),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
              bottom: Radius.circular(24),
            ),
            color: MacosColors.controlColor
                .resolvedColor(context)
                .withOpacity(.03),
          ),
          padding: const EdgeInsets.all(8),
          child: ListenableBuilder(
            listenable:
                Listenable.merge([selectedItems, appMode, progressNotifier]),
            builder: (context, _) {
              if (progressNotifier() != -1) {
                return SizedBox(
                  height: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ProgressBar(
                          value: progressNotifier(),
                        ),
                      ),
                      Text(
                        'Processing: ${(progressNotifier() * 100).toStringAsFixed(2)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }
              return GlassButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: selectedItems().isEmpty ||
                        selectedItems()
                            .every((e) => !appMode().isFileCompatible(e))
                    ? null
                    : () async {
                        switch (appMode()) {
                          case AppMode.convertToIco:
                            await cli.convertToIco(selectedItems().first);
                          case AppMode.convertToWav:
                            progressNotifier.value = 0;
                            await cli.convertToWav(
                              selectedItems().first,
                              onProgress: (progress) {
                                progressNotifier.value = progress;
                              },
                              // onError: () {
                              //   progressNotifier.value = -1;
                              // },
                            );
                            progressNotifier.value = -1;
                          default:
                        }
                      },
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
