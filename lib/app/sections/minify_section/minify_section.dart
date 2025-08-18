import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/app/main_drop/drop_section.dart';
import 'package:shakepin/app/sections/minify_section/minify_settings.dart';
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/app/widgets/error_handler.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/widgets/glass_button.dart';

class MinifySection extends StatelessWidget {
  const MinifySection({super.key, required this.dropSection});

  final DropSection dropSection;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        left: 8.0,
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
                const MinifySettings(),
              ],
            ),
          ),
          ErrorHandler(
            errorMessages: errorMessages,
            sectionName: 'minify',
          ),
        ],
      ),
    );
  }


}
