import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:shakepin/utils/drop_channel.dart';

class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(supportedDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          }),
          (VerticalDragGestureRecognizer instance) {
            instance.onStart = (details) {
              dropChannel.performDragWindow();
            };
          },
        ),
        HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(supportedDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          }),
          (HorizontalDragGestureRecognizer instance) {
            instance.onStart = (details) {
              dropChannel.performDragWindow();
            };
          },
        ),
      },
      child: child,
    );
  }
}
