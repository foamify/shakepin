import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
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
                ListView(
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
      children: [
        _buildLinkText('Website', 'https://github.com/damywise'),
        const SizedBox(height: 10),
        _buildLinkText('GitHub', 'https://github.com/foamify/shakepin'),
      ],
    );
  }

  Widget _buildLinkText(String title, String url) {
    return MouseRegion(
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
            builder: (context) => MacosSheet(
              insetPadding: const EdgeInsets.all(12),
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
      print('Could not launch $url');
    }
  }

  Widget _buildCloseButton(BuildContext context) {
    return MacosIconButton(
      padding: const EdgeInsets.all(4),
      onPressed: _handleCloseButtonPress,
      backgroundColor:
          CupertinoColors.label.resolveFrom(context).withOpacity(.5),
      hoverColor: CupertinoColors.label.resolveFrom(context).withOpacity(.9),
      pressedOpacity: .6,
      icon: Icon(
        FluentIcons.dismiss_24_filled,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        size: 14,
      ),
    );
  }

  Future<void> _handleCloseButtonPress() async {
    isAboutApp.value = false;
  }
}
