import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/side_button.dart';

class MainSidebar extends StatelessWidget {
  const MainSidebar({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.onShowTooltip,
    required this.onHideTooltip,
  });

  final AppMode selectedMode;
  final ValueChanged<AppMode> onModeChanged;
  final void Function(String tooltip) onShowTooltip;
  final VoidCallback onHideTooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        SideButton(
          label: 'pin',
          selected: selectedMode == AppMode.pin,
          tooltip: 'Drop files here to pin them',
          onDragPerform: (paths) {
            items.value = {
              ...items(),
              ...paths.videoPaths,
              ...paths.imagePaths
            };
            onModeChanged(AppMode.pin);
          },
          onShowTooltip: onShowTooltip,
          onHideTooltip: onHideTooltip,
          onTap: () {
            onModeChanged(AppMode.pin);
          },
          child: MacosIcon(
            FluentIcons.pin_24_regular,
            color: MacosColors.labelColor.resolveFrom(context),
          ),
        ),
        SideButton(
          label: 'minify',
          selected: selectedMode == AppMode.minify,
          tooltip: 'Drop images and videos here to minify their size',
          onDragPerform: (paths) {
            items.value = {
              ...items(),
              ...paths.videoPaths,
              ...paths.imagePaths
            };
            onModeChanged(AppMode.minify);
          },
          onShowTooltip: onShowTooltip,
          onHideTooltip: onHideTooltip,
          onTap: () {
            onModeChanged(AppMode.minify);
          },
          child: MacosIcon(
            FluentIcons.arrow_minimize_vertical_24_regular,
            color: MacosColors.labelColor.resolveFrom(context),
          ),
        ),
        SideButton(
          label: 'archive',
          selected: selectedMode == AppMode.archive,
          tooltip: 'Drop files here to archive them into a .zip',
          onDragPerform: (paths) {},
          onShowTooltip: onShowTooltip,
          onHideTooltip: onHideTooltip,
          onTap: () {
            onModeChanged(AppMode.archive);
          },
          child: MacosIcon(
            FluentIcons.archive_24_regular,
            color: MacosColors.labelColor.resolveFrom(context),
          ),
        ),
        SideButton(
          label: 'misc',
          selected: switch (selectedMode) {
            AppMode.pin || AppMode.minify || AppMode.archive => false,
            _ => true,
          },
          tooltip: 'Drop files here to open other tools',
          onDragPerform: (paths) {},
          onShowTooltip: onShowTooltip,
          onHideTooltip: onHideTooltip,
          onTap: () {
            onModeChanged(AppMode.convertToWav);
          },
          child: MacosIcon(
            FluentIcons.apps_24_regular,
            color: MacosColors.labelColor.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}
