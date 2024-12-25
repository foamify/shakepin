import 'package:flutter/material.dart';
import 'package:shakepin/app/main_drop/drop_section.dart';
import 'package:shakepin/app/main_drop/minify_section/minify_settings.dart';

class MinifySection extends StatelessWidget {
  const MinifySection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 4.0,
        right: 8.0,
      ),
      child: Column(
        spacing: 8,
        children: [
          DropSection(),
          MinifySettings(),
        ],
      ),
    );
  }
}
