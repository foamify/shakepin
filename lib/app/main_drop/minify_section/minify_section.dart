import 'package:flutter/material.dart';
import 'package:shakepin/app/main_drop/minify_section/minify_drop_section.dart';
import 'package:shakepin/app/main_drop/minify_section/minify_settings.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

class MinifySection extends StatefulWidget {
  const MinifySection({super.key});

  @override
  State<MinifySection> createState() => _MinifySectionState();
}

class _MinifySectionState extends State<MinifySection> {
  @override
  void initState() {
    init();
    super.initState();
  }

  void init() async {
    dropChannel.setMinimumSize(AppSizes.minify);
    final rect = Rect.fromCenter(
      center: await dropChannel.center(),
      width: AppSizes.minify.width,
      height: AppSizes.minify.height,
    );
    dropChannel.setFrame(rect, animate: true);
  }

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
          MinifyDropSection(),
          MinifySettings(),
        ],
      ),
    );
  }
}
