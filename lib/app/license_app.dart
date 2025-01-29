import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shakepin/utils/license_service.dart';

enum LicenseError {
  invalid('Invalid or expired license key'),
  network('Network error. Please try again'),
  format('Invalid license format'),
  unknown('An unexpected error occurred. Please try again');

  final String message;
  const LicenseError(this.message);
}

class LicenseApp extends StatefulWidget {
  const LicenseApp({super.key});

  @override
  State<LicenseApp> createState() => _LicenseAppState();
}

class _LicenseAppState extends State<LicenseApp> {
  final _licenseController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  LicenseError? _errorType;

  // License key format: SKPN_PERP-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
  final _licenseFormat = RegExp(
      r'^SKPN_PERP-[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$');

  final _manageUrl = Uri.parse('https://polar.sh/purchases/license-keys');

  @override
  void initState() {
    super.initState();
    _licenseController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _licenseController.removeListener(_validateInput);
    _licenseController.dispose();
    super.dispose();
  }

  void _validateInput() {
    setState(() {
      if (_licenseController.text.isEmpty) {
        _errorType = null;
        _errorMessage = null;
      } else if (!_licenseFormat.hasMatch(_licenseController.text)) {
        _errorType = LicenseError.format;
        _errorMessage = _errorType?.message;
      } else {
        _errorType = null;
        _errorMessage = null;
      }
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
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: ValueListenableBuilder(
                    valueListenable: isLicenseValid,
                    builder: (context, isValid, child) {
                      if (isValid) {
                        return Column(
                          children: [
                            const SizedBox(height: 24),
                            _buildAppIcon(),
                            const SizedBox(height: 24),
                            const Text(
                              'Thank You!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your license has been activated successfully',
                              style: TextStyle(
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 8,
                              children: [
                                GlassButton(
                                  onTap: _handleClose,
                                  child: const Text('Start Using ShakePin'),
                                ),
                                GlassButton(
                                  padding: const EdgeInsets.all(8),
                                  radius: 8,
                                  ghost: true,
                                  child: const Icon(
                                    FluentIcons.key_reset_24_regular,
                                    size: 20,
                                  ),
                                  onTap: () => _showDeactivateMenu(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildManageLink(),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          const SizedBox(height: 24),
                          _buildAppIcon(),
                          const SizedBox(height: 24),
                          _buildTitle(),
                          const Spacer(),
                          _buildLicenseInput(),
                          const SizedBox(height: 24),
                          _buildSubmitButton(),
                          const SizedBox(height: 16),
                          _buildManageLink(),
                        ],
                      );
                    },
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

  Widget _buildManageLink() {
    return ContextMenuWidget(
      menuProvider: (context) {
        return Menu(
          children: [
            MenuAction(
              title: 'Copy link to clipboard',
              callback: () async {
                await Clipboard.setData(
                  ClipboardData(text: _manageUrl.toString()),
                );
              },
            ),
          ],
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => launchUrl(_manageUrl),
          child: const Text(
            'Manage license keys →',
            style: TextStyle(
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MacosColors.systemGrayColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Image.asset(
        'assets/images/tray_icon.png',
        width: 32,
        height: 32,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Text(
          'Activate ShakePin',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Please enter your license key to remove the watermark',
          style: TextStyle(
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: MacosColors.separatorColor,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MacosTextField(
                  controller: _licenseController,
                  placeholder: 'SKPN_PERP-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
                  maxLength: 45,
                  enabled: !_isSubmitting,
                  onSubmitted: (_) => _handleSubmit(),
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                  ],
                  onChanged: (value) {
                    if (value.length == 45) {
                      _handleSubmit();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              MacosIconButton(
                icon: const Icon(
                  FluentIcons.clipboard_paste_16_regular,
                  size: 16,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final clipboardData =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (clipboardData?.text != null) {
                          _licenseController.text = clipboardData!.text!;
                        }
                      },
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_circle_fill,
                    size: 14,
                    color: MacosColors.systemRedColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: MacosColors.systemRedColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (_errorType != LicenseError.format)
                          MacosIconButton(
                            icon: const Icon(
                              FluentIcons.arrow_clockwise_16_regular,
                              size: 14,
                              color: MacosColors.systemRedColor,
                            ),
                            onPressed: _handleSubmit,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GlassButton(
      onTap: _isSubmitting ? null : _handleSubmit,
      child: _isSubmitting
          ? const ProgressCircle(radius: 8)
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
    if (_licenseController.text.isEmpty || _errorType == LicenseError.format)
      return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _errorType = null;
    });

    try {
      final licenseService = LicenseService.instance;
      final isActivated =
          await licenseService.activateLicense(_licenseController.text);

      if (isActivated) {
        // Validate license immediately after activation
        final isValid = await licenseService.validateLicense();

        if (!isValid) {
          setState(() {
            _errorType = LicenseError.invalid;
            _errorMessage = 'License activation failed validation';
          });
          await licenseService.clearLicense(); // Clean up invalid license
          return;
        }

        final customerInfo = await licenseService.getCustomerInfo();
        final licenseInfo = await licenseService.getLicenseInfo();

        logger.log(
          'License activated and validated for ${customerInfo?.name}, expires: ${licenseInfo?.expiresAt}',
        );

        licenseService.onLicenseExpiring.listen((expiryDate) {
          // TODO: Show expiration notification to user
        });

        isLicenseValid.value = true;
      } else {
        setState(() {
          _errorType = LicenseError.invalid;
          _errorMessage = _errorType?.message;
        });
      }
    } on LicenseValidationException catch (e) {
      setState(() {
        _errorType = e.code == 'NETWORK_ERROR'
            ? LicenseError.network
            : LicenseError.invalid;
        _errorMessage = _errorType?.message;
      });
    } catch (e) {
      setState(() {
        _errorType = LicenseError.unknown;
        _errorMessage = _errorType?.message;
      });
      logger.log('License validation error: $e', level: LogLevel.error);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showDeactivateMenu(BuildContext context) {
    showMacosAlertDialog(
      barrierColor: MacosTheme.brightnessOf(context).isDark
          ? MacosColors.black.withOpacity(0.4)
          : MacosColors.white.withOpacity(0.4),
      context: context,
      builder: (context) => MacosAlertDialog(
        appIcon: const Icon(
          FluentIcons.warning_16_regular,
          color: MacosColors.systemYellowColor,
          size: 32,
        ),
        title: const Text('Deactivate License?'),
        message: const Text(
          'This will remove the license from this device. You can reactivate it later.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          color: MacosColors.systemRedColor,
          child: const Text('Deactivate'),
          onPressed: () {
            Navigator.pop(context);
            _handleDeactivate();
          },
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _handleDeactivate() async {
    try {
      final licenseService = LicenseService.instance;

      // Call deactivation API
      final success = await licenseService.deactivateLicense();

      if (success) {
        // Clear local storage only if API call succeeds
        await licenseService.clearLicense();
        isLicenseValid.value = false;

        setState(() {
          _licenseController.clear();
          _errorMessage = null;
          _errorType = null;
        });

        logger.log('License deactivated successfully');
      } else {
        logger.log('Failed to deactivate license', level: LogLevel.error);
      }
    } catch (e) {
      logger.log('Error deactivating license: $e', level: LogLevel.error);
    }
  }

  void _handleClose() {
    isLicenseApp.value = false;
    handleModeChanged(AppMode.pin);
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
