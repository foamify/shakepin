import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class CustomDragGesture extends StatefulWidget {
  const CustomDragGesture(
      {super.key, required this.child, required this.onDragStart});

  final Widget child;
  final void Function() onDragStart;

  @override
  State<CustomDragGesture> createState() => _CustomDragGestureState();
}

class _CustomDragGestureState extends State<CustomDragGesture> {
  var isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        print('onPanStart session ${details.kind}');
        if (details.kind == PointerDeviceKind.mouse) {
          // print('onPanStartdragfiles');
          widget.onDragStart();
        }
      },
      child: widget.child,
    );
  }
}
