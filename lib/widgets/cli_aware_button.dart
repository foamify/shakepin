import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/services/cli_tool_availability_service.dart';
import 'package:shakepin/widgets/glass_button.dart';

/// A button that automatically adapts based on CLI tool availability
/// Shows the normal button when tools are available, or an install prompt when missing
class CliAwareButton extends StatelessWidget {
  const CliAwareButton({
    super.key,
    required this.requiredTools,
    required this.onTap,
    required this.child,
    this.onInstallTap,
    this.disabled = false,
    this.padding,
    this.radius,
    this.secondary = false,
  });

  /// List of CLI tools required for this button to function
  final List<String> requiredTools;
  
  /// Callback when the button is tapped (only called when all tools are available)
  final VoidCallback? onTap;
  
  /// Widget to display inside the button
  final Widget child;
  
  /// Optional callback when install button is tapped
  /// If not provided, will open native settings window
  final VoidCallback? onInstallTap;
  
  /// Whether the button should be disabled even when tools are available
  final bool disabled;
  
  /// Button padding
  final EdgeInsets? padding;
  
  /// Button border radius
  final double? radius;
  
  /// Whether to use secondary button style
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cliToolAvailability,
      builder: (context, _) {
        final missingTools = cliToolAvailability.getMissingTools(requiredTools);
        final hasAllTools = missingTools.isEmpty;
        
        if (hasAllTools && !disabled) {
          // All tools available - show normal button
          return GlassButton(
            onTap: onTap,
            padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
            radius: radius,
            secondary: secondary,
            child: child,
          );
        } else if (!hasAllTools) {
          // Some tools missing - show install prompt
          return _buildInstallPrompt(context, missingTools);
        } else {
          // Tools available but button disabled
          return GlassButton(
            onTap: null,
            padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
            radius: radius,
            secondary: secondary,
            child: child,
          );
        }
      },
    );
  }

  Widget _buildInstallPrompt(BuildContext context, List<String> missingTools) {
    final toolName = missingTools.first; // Show prompt for first missing tool
    final displayName = cliToolAvailability.getToolDisplayName(toolName);
    
    return GlassButton(
      onTap: onInstallTap ?? () => _openNativeSettings(context, toolName),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
      radius: radius,
      secondary: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.download_circle,
            size: 16,
            color: MacosColors.systemOrangeColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Install $displayName',
            style: TextStyle(
              color: MacosColors.systemOrangeColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _openNativeSettings(BuildContext context, String toolName) {
    // Use method channel to open native settings window and scroll to CLI tools section
    const platform = MethodChannel('click.shakepin.macos/settings');
    
    try {
      platform.invokeMethod('showSettings');
    } catch (e) {
      // Fallback: show dialog with installation instructions
      _showInstallDialog(context, toolName);
    }
  }

  void _showInstallDialog(BuildContext context, String toolName) {
    final displayName = cliToolAvailability.getToolDisplayName(toolName);
    final installUrl = cliToolAvailability.getInstallationUrl(toolName);
    
    showMacosAlertDialog(
      context: context,
      builder: (context) => MacosAlertDialog(
        appIcon: const FlutterLogo(size: 56),
        title: Text('Install $displayName'),
        message: Text(
          'This feature requires $displayName to be installed. '
          'You can install it through the Settings window or visit the official website.',
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () {
            Navigator.of(context).pop();
            // Try to open settings again
            _openNativeSettings(context, toolName);
          },
          child: const Text('Open Settings'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}