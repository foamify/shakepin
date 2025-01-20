import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop/drop_section.dart';
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/app/sections/misc_section/misc_settings.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/widgets/glass_button.dart';

class MiscSection extends StatelessWidget {
  const MiscSection({super.key, required this.dropSection});

  final DropSection dropSection;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        left: 4.0,
        right: 8.0,
      ),
      child: Column(
        spacing: 8,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height - 20,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 8,
              children: [
                Expanded(child: dropSection),
                const MiscSettings(),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: errorMessages,
            builder: (context, _) {
              if (errorMessages().isNotEmpty) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MacosColors.systemRedColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Errors:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: MacosColors.systemRedColor,
                                ),
                              ),
                              const Spacer(),
                              GlassButton(
                                secondary: true,
                                onTap: () => errorMessages.clear(),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...errorMessages().map((error) => Text(
                                error,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: MacosColors.systemRedColor),
                              )),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
