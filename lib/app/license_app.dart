import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/widgets/glass_button.dart';

class LicenseApp extends StatefulWidget {
  const LicenseApp({super.key});

  @override
  State<LicenseApp> createState() => _LicenseAppState();
}

class _LicenseAppState extends State<LicenseApp> {
  final _licenseController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosScaffold(
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAppIcon(),
                      _buildTitle(),
                      _buildLicenseInput(),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
                _buildDragRegion(),
                _buildCloseButton(context),
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

  Widget _buildTitle() {
    return const Text(
      'Please enter your license key to activate ShakePin',
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLicenseInput() {
    return MacosTextField(
      controller: _licenseController,
      placeholder: 'XXXXX-XXXXX-XXXXX-XXXXX',
      maxLength: 23,
      enabled: !_isSubmitting,
      onSubmitted: (_) => _handleSubmit(),
    );
  }

  Widget _buildSubmitButton() {
    return GlassButton(
      onTap: _isSubmitting ? null : _handleSubmit,
      child: _isSubmitting
          ? const CupertinoActivityIndicator()
          : const Text('Activate'),
    );
  }

  Widget _buildDragRegion() {
    return Positioned(
      top: 0,
      height: 36,
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
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Positioned(
      top: 10,
      left: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8)
            .copyWith(topLeft: const Radius.circular(32)),
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
            onPressed: _handleClose,
            backgroundColor: CupertinoColors.label
                .resolveFrom(context)
                .withValues(alpha: .5),
            hoverColor: CupertinoColors.label
                .resolveFrom(context)
                .withValues(alpha: .9),
            pressedOpacity: .6,
            icon: Icon(
              FluentIcons.dismiss_24_filled,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              size: 14,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_licenseController.text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    // TODO: Implement license validation logic
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call

    setState(() {
      _isSubmitting = false;
    });

    // On successful activation:
    // handleModeChanged(AppMode.pin);
  }

  void _handleClose() {
    isLicenseApp.value = false;
    handleModeChanged(AppMode.pin);
  }
}
