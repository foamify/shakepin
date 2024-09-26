import 'package:flutter/material.dart';
import 'package:shakepin/app/drop_widgets/drop_pin.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

class PanelApp extends StatefulWidget {
  const PanelApp({super.key});

  @override
  State<PanelApp> createState() => _PanelAppState();
}

class _PanelAppState extends State<PanelApp> {
  @override
  void initState() {
    dropChannel.setMinimumSize(AppSizes.panel);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DropPin(),
        // DropMinify(),
        // DropArchive(),
      ],
    );
  }
}
