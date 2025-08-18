import 'package:flutter/material.dart';
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/utils/native_alert.dart';
import 'package:shakepin/utils/cli_tool_helper.dart';

/// A reusable widget that handles error display and user responses for different sections
class ErrorHandler extends StatelessWidget {
  final ValueNotifier<List<String>> errorMessages;
  final String sectionName;

  const ErrorHandler({
    super.key,
    required this.errorMessages,
    required this.sectionName,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: errorMessages,
      builder: (context, _) {
        // Show native alert when errors are added
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (errorMessages.value.isNotEmpty && !isShowingAlert.value) {
            isShowingAlert.value = true;
            final response = await NativeAlert.showErrors(
              errorMessages.value, 
              showRetry: true,
            );
            
            // Detect missing tool before clearing errors
            final missingTool = CliToolHelper.detectMissingToolFromErrors(errorMessages.value);
            
            // Clear errors regardless of user choice
            errorMessages.value = [];
            isShowingAlert.value = false;
            
            // Handle user response
            if (response == 'Retry' || response == 'Retry All') {
              retryTrigger.value = sectionName;
            } else if (response != null && response.startsWith('Install ') && missingTool != null) {
              // Open installation guide for the detected missing tool
              await CliToolHelper.openInstallationGuide(missingTool);
            }
          }
        });
        return const SizedBox.shrink();
      },
    );
  }
}