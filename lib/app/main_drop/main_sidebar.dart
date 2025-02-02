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

  void handleAction(VoidCallback action) {
    if (setupSuccess() != true) {
      isSetupApp.value = true;
      isAboutApp.value = false;
      isLicenseApp.value = false;
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: Listenable.merge([
          setupSuccess,
        ]),
        builder: (context, child) {
          return Column(
            spacing: 8,
            children: [
              SideButton(
                label: 'pin',
                selected: selectedMode == AppMode.pin,
                tooltip: 'Drop files here to pin them',
                onDragPerform: (paths) {
                  final addedPaths = paths;
                  items.value = {
                    ...items(),
                    ...addedPaths,
                  };
                  selectedItems.value = {
                    ...selectedItems(),
                    ...addedPaths,
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
                onDragPerform: (paths) => handleAction(() {
                  final addedPaths = {...paths.videoPaths, ...paths.imagePaths};
                  items.value = {
                    ...items(),
                    ...addedPaths,
                  };
                  selectedItems.value = {
                    ...selectedItems(),
                    ...addedPaths,
                  };
                  onModeChanged(AppMode.minify);
                }),
                onShowTooltip: onShowTooltip,
                onHideTooltip: onHideTooltip,
                onTap: () => handleAction(() {
                  onModeChanged(AppMode.minify);
                }),
                child: MacosIcon(
                  FluentIcons.arrow_minimize_vertical_24_regular,
                  color: MacosColors.labelColor.resolveFrom(context),
                ),
              ),
              SideButton(
                label: 'archive',
                selected: selectedMode == AppMode.archive,
                tooltip: 'Drop files here to archive them into a .zip',
                onDragPerform: (paths) => handleAction(() {
                  final addedPaths = paths;
                  items.value = {
                    ...items(),
                    ...addedPaths,
                  };
                  selectedItems.value = {
                    ...selectedItems(),
                    ...addedPaths,
                  };
                  onModeChanged(AppMode.archive);
                }),
                onShowTooltip: onShowTooltip,
                onHideTooltip: onHideTooltip,
                onTap: () => handleAction(() {
                  onModeChanged(AppMode.archive);
                }),
                child: MacosIcon(
                  FluentIcons.archive_24_regular,
                  color: MacosColors.labelColor.resolveFrom(context),
                ),
              ),
              SideButton(
                label: 'misc',
                selected: switch (selectedMode) {
                  AppMode.panel ||
                  AppMode.pin ||
                  AppMode.minify ||
                  AppMode.archive =>
                    false,
                  _ => true,
                },
                tooltip: 'Drop files here to open other tools',
                onDragPerform: (paths) => handleAction(() {
                  final addedPaths = paths;
                  items.value = {
                    ...items(),
                    ...addedPaths,
                  };
                  selectedItems.value = {
                    ...selectedItems(),
                    ...addedPaths,
                  };
                  handleMiscModeChange(paths);
                }),
                onShowTooltip: onShowTooltip,
                onHideTooltip: onHideTooltip,
                onTap: () => handleAction(() {
                  handleMiscModeChange();
                }),
                child: MacosIcon(
                  FluentIcons.apps_24_regular,
                  color: MacosColors.labelColor.resolveFrom(context),
                ),
              ),
            ],
          );
        });
  }

  void handleMiscModeChange([List<String>? paths]) {
    paths ??= selectedItems().toList();

    if (paths.videoPaths.isNotEmpty) {
      onModeChanged(AppMode.convertToWav);
      return;
    }
    if (paths.imagePaths.isNotEmpty) {
      onModeChanged(AppMode.convertToIco);
      return;
    }
    if (paths.audioPaths.isNotEmpty) {
      onModeChanged(AppMode.convertToWav);
      return;
    }
    if (paths.urls.isNotEmpty) {
      onModeChanged(AppMode.downloadMedia);
      return;
    }

    onModeChanged(AppMode.convertToWav);
  }
}
