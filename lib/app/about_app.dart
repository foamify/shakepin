import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shakepin/oss_licenses.dart';

class AboutApp extends StatefulWidget {
  const AboutApp({super.key});

  @override
  State<AboutApp> createState() => _AboutAppState();
}

class _AboutAppState extends State<AboutApp> {
  String version = '';

  @override
  void initState() {
    super.initState();
    dropChannel.setMinimumSize(AppSizes.about);
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final appVersion = await dropChannel.getAppVersion();
    setState(() {
      version = appVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MacosScaffold(
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Stack(
              children: [
                SuperListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 20),
                    _buildAppIcon(),
                    const SizedBox(height: 20),
                    _buildAppInfo(),
                    const SizedBox(height: 30),
                    _buildDeveloperInfo(),
                    const SizedBox(height: 20),
                    _buildLinks(),
                    const SizedBox(height: 30),
                    _buildLicenses(),
                  ],
                ),
                Positioned(
                  top: 0,
                  height: 24,
                  left: 0,
                  right: 0,
                  child: Listener(
                    onPointerMove: (event) {
                      dropChannel.startDragging();
                    },
                    child: const ColoredBox(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _buildCloseButton(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAppIcon() {
    return Image.asset(
      'assets/images/tray_icon.png',
      width: 16,
      height: 16,
      filterQuality: FilterQuality.medium,
    );
  }

  Widget _buildAppInfo() {
    return Column(
      children: [
        const Text(
          'ShakePin',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Version $version',
          style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context)),
        ),
      ],
    );
  }

  Widget _buildDeveloperInfo() {
    return const Column(
      children: [
        Text(
          'Developed by',
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 4),
        Text(
          'Ahmad Arif Aulia Sutarman',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLinks() {
    return Column(
      spacing: 10,
      children: [
        _buildLinkText('Twitter/X', 'https://github.com/damywise'),
        _buildLinkText('Website', 'https://damywise.com'),
        _buildLinkText('GitHub', 'https://github.com/foamify/shakepin'),
      ],
    );
  }

  Widget _buildLinkText(String title, String url) {
    return ContextMenuWidget(
      menuProvider: (_) => Menu(
        children: [
          MenuAction(
            title: 'Copy Link to Clipboard',
            callback: () async {
              await dropChannel.writeToClipboard(url);
            },
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _launchURL(url),
          child: Text(
            title,
            style: MacosTheme.of(context).typography.body.copyWith(
                  color: MacosColors.systemBlueColor,
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildLicenses() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Open Source Licenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...allDependencies
                .map((package) => _buildLicenseItem(package, constraints)),
          ],
        );
      },
    );
  }

  Widget _buildLicenseItem(Package package, BoxConstraints constraints) {
    return SizedBox(
      width: constraints.maxWidth,
      height: 48,
      child: MacosIconButton(
        backgroundColor: Colors.transparent,
        onPressed: () {
          showMacosSheet(
            context: context,
            barrierColor: MacosTheme.brightnessOf(context).isDark
                ? Colors.black.withAlpha(100)
                : Colors.white.withAlpha(100),
            builder: (context) => MacosSheet(
              insetPadding: const EdgeInsets.all(12).copyWith(top: 36),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(package.description),
                        const SizedBox(height: 16),
                        const Text(
                          'License:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(package.license ??
                            'No license information available'),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: MacosIconButton(
                      icon: const Icon(CupertinoIcons.xmark, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        icon: SizedBox(
          width: constraints.maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle(
                style: MacosTheme.of(context).typography.headline.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                child: Text(package.name),
              ),
              DefaultTextStyle(
                style: MacosTheme.of(context).typography.subheadline.copyWith(
                      color: MacosTheme.brightnessOf(context).isDark
                          ? MacosColors.systemGrayColor
                          : const MacosColor(0xff88888C),
                    ),
                textAlign: TextAlign.start,
                child: Text(package.version),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      launchUrl(Uri.parse(url));
    } else {
      // Handle error
      logger.log('Could not launch $url');
    }
  }

  Widget _buildCloseButton(BuildContext context) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(8).copyWith(topLeft: const Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        blendMode: BlendMode.src,
        child: MacosIconButton(
          borderRadius: BorderRadius.circular(8)
              .copyWith(topLeft: const Radius.circular(32)),
          padding: const EdgeInsets.only(
            left: 6,
            top: 6,
            right: 4,
            bottom: 4,
          ),
          onPressed: _handleCloseButtonPress,
          backgroundColor:
              CupertinoColors.label.resolveFrom(context).withValues(alpha: .5),
          hoverColor:
              CupertinoColors.label.resolveFrom(context).withValues(alpha: .9),
          pressedOpacity: .6,
          icon: Icon(
            FluentIcons.dismiss_24_filled,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            size: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _handleCloseButtonPress() async {
    isAboutApp.value = false;
    handleModeChanged(AppMode.pin);
  }
}
