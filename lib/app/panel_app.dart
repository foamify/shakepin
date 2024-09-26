import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:shakepin/app/drop_widgets/drop_archive.dart';
import 'package:shakepin/app/drop_widgets/drop_minify.dart';
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
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DropPin(
            icon: Icon(
              FluentIcons.pin_24_regular,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          DropMinify(
            icon: Icon(
              FluentIcons.arrow_minimize_vertical_24_regular,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          DropArchive(
            icon: Icon(
              FluentIcons.archive_24_regular,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
