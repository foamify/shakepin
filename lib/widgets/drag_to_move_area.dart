import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:shakepin/utils/drop_channel.dart';

class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(supportedDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          }),
          (PanGestureRecognizer instance) {
            instance.onStart = (details) {
              print('onPanStart');
              dropChannel.performDragWindow();
            };
          },
        ),
      },
      child: child,
    );
  }
}
