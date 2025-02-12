import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/handle_menu_item.dart';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:window_manager/window_manager.dart';

typedef ShakeDetectedCallback = void Function(double x, double y);
typedef DraggingSessionEndedCallback = void Function(int operation);
typedef MenuItemClickedCallback = void Function(int tag);
typedef ConcludeCallback = void Function();
typedef CliOutputCallback = void Function(String output);
typedef CliErrorCallback = void Function(String error);

const MethodChannel _channel = MethodChannel('click.shakepin.macos/drop');

final dropChannel = DropChannel._();

enum PopoverEdge { left, right, top, bottom }

class DropChannel {
  DropChannel._() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'shakeDetected':
          final List<double> args = call.arguments.cast<double>();
          for (final listener in listeners) {
            listener.shakeDetected(Offset(args[0], args[1]));
          }

        case 'draggingSessionEnded':
          final int operation = call.arguments;
          for (final listener in listeners) {
            listener.onDragSessionEnded(switch (operation) {
              1 => DropOperation.copy,
              16 => DropOperation.move,
              _ => throw Exception('Invalid operation'),
            });
          }

        case 'menuItemClicked':
          final int tag = call.arguments;
          handleMenuItemClicked(tag);

        case 'conclude':
          for (final listener in listeners) {
            listener.onDragConclude();
          }

        case 'dragStart':
          for (final e in listeners) {
            e.onDragStart();
          }

        case 'dragEnter':
          final args = call.arguments;
          listeners
              .firstWhere((element) => element.label == args[0])
              .onDragEnter(Offset(args[1] as double, args[2] as double));

        case 'dragExited':
          listeners
              .firstWhere((element) => element.label == call.arguments)
              .onDragExited();

        case 'dragConclude':
          for (var listener in listeners) {
            listener.onDragConclude();
          }

        case 'dragPerform':
          final args = call.arguments;
          listeners
              .firstWhere((element) => element.label == args[0])
              .onDragPerform(List<String>.from(args[1]));

        case 'dragUpdated':
          final args = call.arguments;
          listeners
              .firstWhere((element) => element.label == args[0])
              .onDraggingUpdated(Offset(args[1] as double, args[2] as double));

        case 'cliOutput':
          // logger.log('CLI output: ${call.arguments}');
          for (final callback in _cliOutputCallbacks) {
            callback(call.arguments);
          }

        case 'cliError':
          // logger.log('CLI error: ${call.arguments}');
          for (final callback in _cliErrorCallbacks) {
            callback(call.arguments);
          }

        case 'locationChange':
          final args = call.arguments as Map;
          for (final listener in listeners) {
            listener.onLocationChange(
              hwnd: args['hwnd'] as int,
              idObject: args['idObject'] as int,
              idChild: args['idChild'] as int,
              thread: args['thread'] as int,
              time: args['time'] as int,
              isShiftPressed: args['isShiftPressed'] as bool,
            );
          }
          break;

        default:
          logger.log('DropChannel: unknown method ${call.method}');
      }
    });
  }
  final listeners = <DragDropListener>[];

  final List<CliOutputCallback> _cliOutputCallbacks = [];
  final List<CliErrorCallback> _cliErrorCallbacks = [];

  void addCliOutputCallback(CliOutputCallback callback) {
    _cliOutputCallbacks.add(callback);
  }

  void addCliErrorCallback(CliErrorCallback callback) {
    _cliErrorCallbacks.add(callback);
  }

  void removeCliOutputCallback(CliOutputCallback callback) {
    _cliOutputCallbacks.remove(callback);
  }

  void removeCliErrorCallback(CliErrorCallback callback) {
    _cliErrorCallbacks.remove(callback);
  }

  void clearCliCallbacks() {
    _cliOutputCallbacks.clear();
    _cliErrorCallbacks.clear();
  }

  void removeAllCallbacks() {
    _cliOutputCallbacks.clear();
    _cliErrorCallbacks.clear();
  }

  Future<void> cleanup() async {
    try {
      await _channel.invokeMethod('cleanup');
    } on PlatformException catch (e) {
      throw FlutterError('Error during cleanup: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error during cleanup: $e');
    }
  }

  Future<void> setTrayIcon(Uint8List iconData) async {
    await _channel.invokeMethod('setTrayIcon', iconData);
  }

  Future<void> hide() async {
    if (Platform.isWindows) {
      await windowManager.hide();
      return;
    }
    await _channel.invokeMethod('hide');
  }

  Future<void> performDragWindow() async {
    await _channel.invokeMethod('performDragWindow');
  }

  Future<void> performDragSession(List<String> fileURLs) async {
    await _channel.invokeMethod('performDragSession', fileURLs);
  }

  Future<Uint8List> getFileIcon(String path) async {
    return await _channel.invokeMethod('getFileIcon', path);
  }

  Future<void> setFrame(Rect rect,
      {required bool animate,
      bool usePosition = true,
      bool useSize = true}) async {
    if (Platform.isWindows) {
      // Get the current mouse position and screen info
      final mousePosition = await screenRetriever.getCursorScreenPoint();
      final screens = await screenRetriever.getAllDisplays();
      final screen = screens.firstWhere(
          (element) => (element.visiblePosition! & element.visibleSize!)
              .contains(mousePosition),
          orElse: () => screens.first);
      if (screen == null) {
        throw FlutterError('Unable to determine current screen');
      }

      // Constrain the frame to the screen bounds
      final screenFrame = screen.visiblePosition! & screen.visibleSize!;
      final double constrainedX = usePosition
          ? (rect.left).clamp(
              screenFrame.left, screenFrame.right - (useSize ? rect.width : 0))
          : rect.left;
      final double constrainedY = usePosition
          ? (rect.top).clamp(
              screenFrame.top, screenFrame.bottom - (useSize ? rect.height : 0))
          : rect.top;

      final bounds = Rect.fromLTWH(
          constrainedX,
          constrainedY,
          useSize ? rect.width : rect.width,
          useSize ? rect.height : rect.height);
      if (animate) {
        final current = await windowManager.getBounds();
        const duration = Durations.short4;
        final startTime = DateTime.now();
        const curve = Curves.fastEaseInToSlowEaseOut;

        while (true) {
          final elapsed = DateTime.now().difference(startTime);
          if (elapsed >= duration) break;

          final progress = elapsed.inMilliseconds / duration.inMilliseconds;
          // Ease out cubic interpolation
          final t = curve.transform(progress);

          final interpolatedPosition = usePosition
              ? Offset.lerp(current.topLeft, bounds.topLeft, t)!
              : current.topLeft;
          final interpolatedSize =
              useSize ? Size.lerp(current.size, bounds.size, t)! : current.size;

          await windowManager.setBounds(
            null,
            position: usePosition ? interpolatedPosition : null,
            size: useSize ? interpolatedSize : null,
          );

          await Future.delayed(const Duration(milliseconds: 16)); // ~60fps
        }
      }

      // Set final position
      await windowManager.setBounds(
        null,
        position: usePosition ? bounds.topLeft : null,
        size: useSize ? bounds.size : null,
      );
      return;
    }

    await _channel.invokeMethod('setFrame', [
      usePosition ? rect.left : null,
      usePosition ? rect.top : null,
      useSize ? rect.width : null,
      useSize ? rect.height : null,
      animate,
    ]);
  }

  Future<void> setMinimumSize(Size size) async {
    if (Platform.isWindows) {
      await windowManager.setMinimumSize(size);
      return;
    }
    await _channel.invokeMethod('setMinimumSize', [size.width, size.height]);
  }

  Future<void> setVisible(bool visible) async {
    if (Platform.isWindows) {
      print('setVisible to $visible');
      const duration = Durations.short4;
      final startTime = DateTime.now();
      const curve = Curves.fastEaseInToSlowEaseOut;
      final startOpacity = visible ? 0.0 : 1.0;
      final endOpacity = visible ? 1.0 : 0.0;

      while (true) {
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed >= duration) break;

        final progress = elapsed.inMilliseconds / duration.inMilliseconds;
        final t = curve.transform(progress);
        final opacity = lerpDouble(startOpacity, endOpacity, t)!;
        await windowManager.setOpacity(opacity);
        await Future.delayed(const Duration(milliseconds: 16));
      }

      await windowManager.setOpacity(endOpacity);
      if (visible) {
        handleModeChanged(appMode());
      }
      return;
    }
    await _channel.invokeMethod('setVisible', visible);
  }

  Future<void> orderFront() async {
    if (Platform.isWindows) {
      await windowManager.focus();
      return;
    }
    await _channel.invokeMethod('orderFront');
  }

  Future<void> removeDropTarget(String label) async {
    if (Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod('removeDropTarget', [label]);
  }

  Future<void> setDropTarget(Rect rect, String label) async {
    if (Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod(
        'setDropTarget', [rect.left, rect.top, rect.width, rect.height, label]);
  }

  Future<bool> isVisible() async {
    if (Platform.isWindows) {
      return await windowManager.isVisible();
    }
    return await _channel.invokeMethod('isVisible');
  }

  Future<Offset> center() async {
    if (Platform.isWindows) {
      final bounds = await windowManager.getBounds();
      return bounds.center;
    }
    final List<dynamic> args = await _channel.invokeMethod('center');
    return Offset(args[0] as double, args[1] as double);
  }

  Future<String?> convertToPng(String inputPath) async {
    try {
      final result = await _channel.invokeMethod('convertToPng', [inputPath]);
      return result as String?;
    } on PlatformException catch (e) {
      throw FlutterError('Error converting image to PNG: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error converting image to PNG: $e');
    }
  }

  Future<String?> convertImage(String inputPath, ImageFormat format) async {
    try {
      final result = await _channel
          .invokeMethod('convertImage', [inputPath, format.index]);
      return result as String?;
    } on PlatformException catch (e) {
      throw FlutterError('Error converting image: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error converting image: $e');
    }
  }

  Future<void> showPopover(String content,
      {PopoverEdge edge = PopoverEdge.bottom}) async {
    await _channel.invokeMethod('showPopover', [content, edge.index]);
  }

  Future<void> hidePopover() async {
    if (Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod('hidePopover');
  }

  Future<String> getAppVersion() async {
    if (Platform.isWindows) {
      //TODO: Implement this for Windows
      print('getAppVersion not implemented for Windows');
      return 'UNKNOWN';
    }
    try {
      final String version = await _channel.invokeMethod('getAppVersion');
      return version;
    } on PlatformException catch (e) {
      throw FlutterError('Error getting app version: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error getting app version: $e');
    }
  }

  Future<void> shareXFiles(List<XFile> xFiles) async {
    try {
      final filePaths = xFiles.map((xFile) => xFile.path).toList();
      await _channel.invokeMethod('shareXFiles', filePaths);
    } on PlatformException catch (e) {
      throw FlutterError('Error sharing files: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error sharing files: $e');
    }
  }

  Future<ProcessResult> startProcess(
      String command, List<String> arguments) async {
    try {
      final result = await _channel.invokeMethod('startProcess', {
        'command': command,
        'arguments': arguments.map((e) => "'$e'").toList(),
      });

      return ProcessResult(
        0, // pid (not available from native side)
        int.parse(result['exitCode'].toString()),
        result['output'] as String,
        result['error'] as String,
      );
    } on PlatformException catch (e) {
      throw FlutterError('Error starting process: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error starting process: $e');
    }
  }

  Future<bool> cancelProcess() async {
    try {
      final result = await _channel.invokeMethod('cancelProcess');
      return result as bool;
    } on PlatformException catch (e) {
      throw FlutterError('Error canceling process: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error canceling process: $e');
    }
  }

  Future<bool> isProcessRunning() async {
    try {
      final result = await _channel.invokeMethod('isProcessRunning');
      return result as bool;
    } on PlatformException {
      return false;
    }
  }

  void startDragging() async {
    if (Platform.isWindows) {
      await windowManager.startDragging();
      return;
    }
    _channel.invokeMethod('startDragging');
  }

  Future<void> setShiftKeyCheckEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setShiftKeyCheckEnabled', enabled);
    } on PlatformException catch (e) {
      throw FlutterError('Error setting shift key check: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error setting shift key check: $e');
    }
  }

  void addListener(DragDropListener listener) {
    listeners.add(listener);
  }

  void removeListener(DragDropListener listener) {
    listeners.remove(listener);
  }
}

enum DropOperation {
  move,
  copy,
  link,
}

mixin class DragDropListener {
  String label = '';

  void onDragStart() {}
  void onDragEnter(Offset position) {}
  void onDragExited() {}
  void onDragConclude() {}
  void onDraggingUpdated(Offset position) {}
  void onDragPerform(List<String> paths) {}
  void shakeDetected(Offset position) {}
  void onDragSessionEnded(DropOperation operation) {}
  void onLocationChange({
    required int hwnd,
    required int idObject,
    required int idChild,
    required int thread,
    required int time,
    required bool isShiftPressed,
  }) {}
}
