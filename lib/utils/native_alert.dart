import 'package:flutter/services.dart';
import 'package:shakepin/utils/cli_tool_helper.dart';

class NativeAlert {
  static const MethodChannel _channel = MethodChannel('click.shakepin.macos/drop');

  /// Shows a native macOS alert dialog with customizable options
  static Future<String?> showAlert({
    required String title,
    required String message,
    String style = 'warning', // 'critical', 'warning', 'informational'
    List<String> buttons = const ['OK'],
  }) async {
    try {
      final result = await _channel.invokeMethod('showNativeAlert', {
        'title': title,
        'message': message,
        'style': style,
        'buttons': buttons,
      });
      return result as String?;
    } catch (e) {
      // Fallback to console logging if native alert fails
      print('Native alert failed: $e');
      print('Alert - $title: $message');
      return null;
    }
  }

  /// Shows a native alert for error messages with retry option
  static Future<String?> showError(String message, {bool showRetry = false}) async {
    final friendlyMessage = _formatErrorMessage(message);
    final buttons = showRetry ? ['Retry', 'Cancel'] : ['OK'];
    
    return await showAlert(
      title: 'Something went wrong',
      message: friendlyMessage,
      style: 'critical',
      buttons: buttons,
    );
  }

  /// Shows a native alert for multiple error messages with options
  static Future<String?> showErrors(List<String> errors, {bool showRetry = false}) async {
    if (errors.isEmpty) return null;
    
    String title;
    String message;
    final missingTool = CliToolHelper.detectMissingToolFromErrors(errors);
    
    if (errors.length == 1) {
      title = 'Something went wrong';
      message = _formatErrorMessage(errors.first);
    } else {
      title = 'Multiple issues occurred';
      final formattedErrors = errors.take(3).map(_formatErrorMessage).map((e) => '• $e').join('\n');
      if (errors.length > 3) {
        message = '$formattedErrors\n• ... and ${errors.length - 3} more issues';
      } else {
        message = formattedErrors;
      }
    }
    
    // Determine buttons based on error type
    List<String> buttons;
    if (missingTool != null) {
      final installButtonText = CliToolHelper.getInstallButtonText(missingTool);
      buttons = showRetry ? [installButtonText, 'Retry All', 'Cancel'] : [installButtonText, 'OK'];
    } else {
      buttons = showRetry ? ['Retry All', 'Cancel'] : ['OK'];
    }
    
    return await showAlert(
      title: title,
      message: message,
      style: 'critical',
      buttons: buttons,
    );
  }

  /// Formats technical error messages into user-friendly text
  static String _formatErrorMessage(String error) {
    String formatted = error;
    
    // Extract filename from full path for context
    String? filename;
    final filePathMatch = RegExp(r'([^/\\]+\.[a-zA-Z0-9]+)').firstMatch(error);
    if (filePathMatch != null) {
      filename = filePathMatch.group(1);
    }
    
    // CLI tool-specific error patterns
    final missingTool = CliToolHelper.detectMissingTool(error);
    if (missingTool != null) {
      final toolDisplayName = CliToolHelper.getDisplayName(missingTool);
      return '$toolDisplayName is required but not installed. Please install $toolDisplayName to continue.';
    }
    
    if (error.contains('Error getting video duration')) {
      return filename != null 
        ? 'Unable to read video file "$filename". The file may be corrupted or in an unsupported format.'
        : 'Unable to read video file. The file may be corrupted or in an unsupported format.';
    }
    
    if (error.contains('Minification failed, no output path returned')) {
      return filename != null
        ? 'Failed to process "$filename". Please try again or check if the file is valid.'
        : 'Processing failed. Please try again or check if the file is valid.';
    }
    
    // Common system error patterns
    final errorMappings = {
      RegExp(r'No such file or directory'): 'File not found or has been moved',
      RegExp(r'Permission denied'): 'Permission denied - unable to access the file',
      RegExp(r'Invalid argument'): 'Invalid file format or corrupted file',
      RegExp(r'File exists'): 'A file with this name already exists',
      RegExp(r'Directory not empty'): 'Folder is not empty',
      RegExp(r'Operation not permitted'): 'Operation not allowed by system',
      RegExp(r'Network is unreachable'): 'Network connection issue',
      RegExp(r'Connection refused'): 'Unable to connect to service',
      RegExp(r'Timeout'): 'Operation timed out - please try again',
      RegExp(r'Out of memory'): 'Not enough memory available',
      RegExp(r'Disk full'): 'Not enough disk space available',
    };
    
    for (final mapping in errorMappings.entries) {
      if (mapping.key.hasMatch(formatted)) {
        formatted = mapping.value;
        if (filename != null && !formatted.contains('"')) {
          formatted = 'Error with "$filename": $formatted';
        }
        return formatted;
      }
    }
    
    // Generic cleanup for remaining errors
    // Remove "Failed to minify" prefix and full paths
    formatted = formatted.replaceAll(RegExp(r'^Failed to minify [^:]+: '), '');
    
    // Remove full file paths but keep filename
    if (filename != null) {
      formatted = formatted.replaceAll(RegExp(r'/[^/\s]*$filename'), '"$filename"');
      formatted = formatted.replaceAll(RegExp(r'/[^/\s]+/[^/\s]+/[^/\s]+'), '');
    }
    
    // Remove "Exception:" prefix
    formatted = formatted.replaceAll(RegExp(r'^Exception: '), '');
    
    // Capitalize first letter
    if (formatted.isNotEmpty) {
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    }
    
    // Add context if we have a filename but the message doesn't mention it
    if (filename != null && !formatted.contains(filename) && !formatted.contains('"')) {
      formatted = 'Error processing "$filename": $formatted';
    }
    
    return formatted.isNotEmpty ? formatted : 'An unexpected error occurred';
  }
}