import 'package:flutter/services.dart';
import 'package:shakepin/utils/handle_menu_item.dart';
import 'package:flutter/foundation.dart';

typedef ShakeDetectedCallback = void Function(double x, double y);
typedef DraggingSessionEndedCallback = void Function(int operation);
typedef MenuItemClickedCallback = void Function(int tag);
typedef ConcludeCallback = void Function();

const MethodChannel _channel = MethodChannel('click.shakepin.macos/drop');

final dropChannel = DropChannel._();

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
          for (var element in listeners) {
            element.onDragConclude();
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

        default:
        // print('DropChannel: unknown method ${call.method}');
      }
    });
  }
  final listeners = <DragDropListener>[];

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
    await _channel.invokeMethod('setFrame', [
      usePosition ? rect.left : null,
      usePosition ? rect.top : null,
      useSize ? rect.width : null,
      useSize ? rect.height : null,
      animate,
    ]);
  }

  Future<void> setMinimumSize(Size size) async {
    await _channel.invokeMethod('setMinimumSize', [size.width, size.height]);
  }

  Future<void> setVisible(bool visible) async {
    await _channel.invokeMethod('setVisible', visible);
  }

  Future<void> orderFront() async {
    await _channel.invokeMethod('orderFront');
  }

  Future<void> removeDropTarget(String label) async {
    await _channel.invokeMethod('removeDropTarget', [label]);
  }

  Future<void> setDropTarget(Rect rect, String label) async {
    await _channel.invokeMethod(
        'setDropTarget', [rect.left, rect.top, rect.width, rect.height, label]);
  }

  Future<bool> isVisible() async {
    return await _channel.invokeMethod('isVisible');
  }

  Future<Offset> center() async {
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
      final result = await _channel.invokeMethod('convertImage', [inputPath, format.index]);
      return result as String?;
    } on PlatformException catch (e) {
      throw FlutterError('Error converting image: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error converting image: $e');
    }
  }

  Future<void> showPopover(String content) async {
    await _channel.invokeMethod('showPopover', content);
  }

  Future<void> hidePopover() async {
    await _channel.invokeMethod('hidePopover');
  }

  Future<String> getAppVersion() async {
    try {
      final String version = await _channel.invokeMethod('getAppVersion');
      return version;
    } on PlatformException catch (e) {
      throw FlutterError('Error getting app version: ${e.message}');
    } catch (e) {
      throw FlutterError('Unexpected error getting app version: $e');
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

  void onDragEnter(Offset position) {}
  void onDragExited() {}
  void onDragConclude() {}
  void onDraggingUpdated(Offset position) {}
  void onDragPerform(List<String> paths) {}
  void shakeDetected(Offset position) {}
  void onDragSessionEnded(DropOperation operation) {}
}

enum ImageFormat {
  png,
  jpeg,
  tiff,
  webp,
}
