import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:url_launcher/url_launcher.dart';

class LicenseApp extends StatefulWidget {
  const LicenseApp({super.key});

  @override
  State<LicenseApp> createState() => _LicenseAppState();
}

class _LicenseAppState extends State<LicenseApp> {
  final _licenseController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

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
      _errorMessage = _licenseController.text.isNotEmpty &&
              !_licenseFormat.hasMatch(_licenseController.text)
          ? 'Invalid license format'
          : null;
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAppIcon(),
                      const SizedBox(height: 24),
                      _buildTitle(),
                      const SizedBox(height: 32),
                      _buildLicenseInput(),
                      const SizedBox(height: 24),
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
    return Column(
      children: [
        const Text(
          'Activate ShakePin',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
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
                    LicenseKeyFormatter(),
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
                icon: Icon(
                  CupertinoIcons.doc_on_clipboard,
                  size: 16,
                ),
                onPressed: _isSubmitting ? null : () async {
                  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
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
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: MacosColors.systemRedColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // AI: change style  ...
              ContextMenuWidget(
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
                // underline text, AI!
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => launchUrl(_manageUrl),
                    child: const Text(
                      'Manage license keys →',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              // into like a link. AI!
            ],
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
    if (_licenseController.text.isEmpty || _errorMessage != null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // TODO: Implement secure license validation logic
      final isValid = await _validateLicense(_licenseController.text);

      if (isValid) {
        // Store license securely
        handleModeChanged(AppMode.pin);
        isLicenseApp.value = false;
      } else {
        setState(() {
          _errorMessage = 'Invalid license key';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<bool> _validateLicense(String license) async {
    // TODO: Implement secure license validation with proper encryption
    // 1. Use HTTPS for communication
    // 2. Implement rate limiting
    // 3. Add request signing
    // 4. Use proper error handling
    await Future.delayed(const Duration(seconds: 1));
    return false;
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

class LicenseKeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^A-Z0-9_]'), '');
    final buffer = StringBuffer();

    // Handle the prefix
    if (text.length >= 4 && !text.startsWith('SKPN')) {
      text = 'SKPN${text.substring(4)}';
    }

    // Format the text according to the pattern
    for (int i = 0; i < text.length && i < 41; i++) {
      if (i == 4) {
        buffer.write('_');
      } else if (i == 8) {
        buffer.write('-');
      } else if (i > 8 && ((i - 8) % 4 == 0) && (i < 24)) {
        buffer.write('-');
      } else if (i == 24) {
        buffer.write('-');
      }
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
