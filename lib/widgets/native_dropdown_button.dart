import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/utils/utils.dart';

class DropdownChannel {
  static const channel =
      MethodChannel('com.damywise.flutter_macos_native_dropdown/channel');
  static final _instance = DropdownChannel._();

  DropdownChannel._();

  static DropdownChannel get instance => _instance;

  Future<void> initialize() async {
    channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    logger.log('call: ${call.method}, args: ${call.arguments}');
    switch (call.method) {
      case 'onDropdownMenuSelected':
        DropdownManager.handleMethodCall(call);
      default:
        logger.log('unknown method: ${call.method}');
    }
  }
}

const Radius _kSideRadius = Radius.circular(5.0);
const BorderRadius _kBorderRadius = BorderRadius.all(_kSideRadius);

class DropdownManager {
  static final Map<String, _NativeDropdownButtonState> _dropdowns = {};
  static int _counter = 0;

  static String registerDropdown(_NativeDropdownButtonState state) {
    final id = 'dropdown_${_counter++}';
    _dropdowns[id] = state;
    return id;
  }

  static void unregisterDropdown(String id) {
    _dropdowns.remove(id);
  }

  static void handleSelection(String id, int index) {
    _dropdowns[id]?.handleSelection(index);
  }

  static void handleMethodCall(MethodCall call) {
    if (call.method == 'onDropdownMenuSelected') {
      if (call.arguments is Map) {
        final args = call.arguments as Map;
        final id = args['id'] as String;
        final index = args['index'] as int;
        handleSelection(id, index);
      }
    }
  }
}

class NativeDropdownButton<T> extends StatefulWidget {
  /// The list of items to display in the dropdown.
  ///
  /// NOTE: For pullsDown functionality, a placeholder empty item must be added
  /// as the first item in the list, since the first item may not display properly
  /// for unknown technical reasons.
  final List<NativeDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final Widget? child;
  final bool secondary;
  final ControlSize controlSize;
  final String? tooltip;
  final bool enabled;

  /// Whether the dropdown button pulls items down.
  ///
  /// NOTE: pullsDown requires adding a placeholder empty item at the beginning of the items list
  /// since for unknown technical reasons, the first item won't be displayed.
  final bool pullsDown;
  final bool disableTrailing;
  final EdgeInsetsGeometry? padding;

  const NativeDropdownButton({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.child,
    this.secondary = false,
    this.controlSize = ControlSize.regular,
    this.tooltip,
    this.enabled = true,
    this.pullsDown = false,
    this.disableTrailing = false,
    this.padding,
  });

  @override
  State<NativeDropdownButton<T>> createState() =>
      _NativeDropdownButtonState<T>();
}

class _NativeDropdownButtonState<T> extends State<NativeDropdownButton<T>>
    with WidgetsBindingObserver {
  bool _isHovered = false;
  bool _hasPrimaryFocus = false;
  late FocusHighlightMode _focusHighlightMode;
  FocusNode? _internalNode;
  FocusNode? get focusNode => _internalNode;
  late final String dropdownId;

  @override
  void initState() {
    super.initState();
    _internalNode = FocusNode(debugLabel: '${widget.runtimeType}');
    focusNode!.addListener(_handleFocusChanged);
    final FocusManager focusManager = WidgetsBinding.instance.focusManager;
    _focusHighlightMode = focusManager.highlightMode;
    focusManager.addHighlightModeListener(_handleFocusHighlightModeChange);
    dropdownId = DropdownManager.registerDropdown(this);
    DropdownChannel.instance.initialize();
  }

  void _handleFocusChanged() {
    if (_hasPrimaryFocus != focusNode!.hasPrimaryFocus) {
      setState(() => _hasPrimaryFocus = focusNode!.hasPrimaryFocus);
    }
  }

  void _handleFocusHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted) {
      return;
    }
    setState(() => _focusHighlightMode = mode);
  }

  bool get _showHighlight {
    switch (_focusHighlightMode) {
      case FocusHighlightMode.touch:
        return false;
      case FocusHighlightMode.traditional:
        return _hasPrimaryFocus;
    }
  }

  void handleSelection(int index) {
    if (index >= 0 && index < widget.items.length) {
      widget.onChanged?.call(widget.items[index].value);
    }
  }

  void _updateNativeControl({bool remove = false}) {
    if (remove) {
      DropdownChannel.channel.invokeMethod('updateNativeDropdown', {
        'dropdownId': dropdownId,
        'items': [],
        'x': 0,
        'y': 0,
        'width': 0,
        'height': 0,
        'selectedIndex': 0,
        'enabled': false,
        'remove': true,
        'pullsDown': false,
      });
      return;
    }
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final selectedIndex = widget.value == null
        ? -1
        : widget.items.indexWhere((item) => item.value == widget.value);

    DropdownChannel.channel.invokeMethod('updateNativeDropdown', {
      'dropdownId': dropdownId,
      'items': widget.items
          .map((item) => {
                'title': item.label,
                'enabled': item.enabled,
              })
          .toList(),
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
      'selectedIndex': selectedIndex,
      'enabled': widget.enabled,
      'remove': remove,
      'pullsDown': widget.pullsDown,
    });
  }

  @override
  void dispose() {
    _updateNativeControl(remove: true);
    DropdownManager.unregisterDropdown(dropdownId);
    focusNode?.removeListener(_handleFocusChanged);
    WidgetsBinding.instance.focusManager
        .removeHighlightModeListener(_handleFocusHighlightModeChange);
    _internalNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyles = _getButtonStyles(widget.enabled, context);
    final brightness = MacosTheme.of(context).brightness;
    final isEnabledFactor = widget.enabled ? 1.0 : 0.5;

    return IntrinsicWidth(
      child: Focus(
        focusNode: focusNode,
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            _updateNativeControl();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            _updateNativeControl(remove: true);
          },
          child: Stack(
            children: [
              Container(
                height: widget.controlSize == ControlSize.large ? 28 : 20,
                decoration: _showHighlight
                    ? const BoxDecoration(
                        color: MacosColors.systemGrayColor,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      )
                    : BoxDecoration(
                        gradient: _isHovered && widget.enabled
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: brightness == Brightness.light
                                    ? [
                                        MacosColor.fromRGBO(255, 255, 255,
                                            1.0 * isEnabledFactor),
                                        MacosColor.fromRGBO(255, 255, 255,
                                            1.0 * isEnabledFactor),
                                      ]
                                    : [
                                        MacosColor.fromRGBO(255, 255, 255,
                                            0.251 * isEnabledFactor),
                                        MacosColor.fromRGBO(255, 255, 255,
                                            0.251 * isEnabledFactor),
                                      ],
                              )
                            : null,
                        borderRadius: _kBorderRadius,
                        color: _isHovered ? null : Colors.transparent,
                        boxShadow: _isHovered && widget.enabled
                            ? [
                                BoxShadow(
                                  color: MacosColor.fromRGBO(
                                      0, 0, 0, 0.4 * isEnabledFactor),
                                  blurRadius: 0.5,
                                  offset: brightness == Brightness.dark
                                      ? Offset.zero
                                      : const Offset(0.0, 0.3),
                                  spreadRadius: 0.0,
                                  blurStyle: brightness == Brightness.dark
                                      ? BlurStyle.outer
                                      : BlurStyle.normal,
                                ),
                              ]
                            : null,
                      ),
                foregroundDecoration: _isHovered &&
                        !_showHighlight &&
                        widget.enabled
                    ? BoxDecoration(
                        border: brightness == Brightness.dark
                            ? GradientBoxBorder(
                                gradient: LinearGradient(
                                  colors: [
                                    MacosColor.fromRGBO(
                                        255, 255, 255, 0.25 * isEnabledFactor),
                                    const MacosColor.fromRGBO(
                                        255, 255, 255, 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.2],
                                ),
                                width: 0.7,
                              )
                            : Border.all(
                                width: .5,
                                color: widget.enabled
                                    ? brightness == Brightness.light
                                        ? MacosColors.controlColor
                                            .withValues(alpha: .05)
                                        : const Color(0xFF007AFF)
                                    : buttonStyles.borderColor,
                              ),
                        borderRadius: _kBorderRadius,
                      )
                    : null,
                padding: widget.padding ??
                    const EdgeInsets.only(left: 8.0, right: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.disableTrailing) const Spacer(),
                    DefaultTextStyle(
                      style: MacosTheme.of(context).typography.body.copyWith(
                            color: buttonStyles.textColor,
                          ),
                      child: widget.child ?? const SizedBox(),
                    ),
                    if (!widget.disableTrailing)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CustomPaint(
                            painter: _UpDownCaretsPainter(
                              color: buttonStyles.caretColor,
                              backgroundColor: _isHovered
                                  ? MacosColors.transparent
                                  : buttonStyles.caretBgColor,
                              borderColor: _isHovered
                                  ? MacosColors.transparent
                                  : buttonStyles.caretColor
                                      .withValues(alpha: .05),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // TODO: Popup button looks terrible. Must fix later
              if (Platform.isWindows)
                Opacity(
                  opacity: 0,
                  child: IgnorePointer(
                    ignoring: false,
                    child: MacosPopupButton(
                      value: widget.value,
                      onChanged: widget.onChanged,
                      items: widget.items
                          .map(
                            (item) => MacosPopupMenuItem(
                              value: item.value,
                              enabled: item.enabled,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _ButtonStyles _getButtonStyles(bool enabled, BuildContext context) {
    final theme = MacosTheme.of(context);
    final brightness = theme.brightness;
    Color textColor = theme.typography.body.color!;
    Color bgColor = MacosColors.systemGrayColor;
    Color borderColor = brightness.resolve(
      const Color(0xffc3c4c9),
      const Color(0xff222222),
    );
    Color caretColor = MacosColors.controlTextColor.resolvedColor(context);
    Color caretBgColor =
        MacosColors.controlColor.resolvedColor(context).withValues(alpha: .05);
    if (!enabled) {
      caretBgColor = MacosColors.transparent;
      textColor = caretColor = brightness.resolve(
        MacosColors.disabledControlTextColor.color,
        MacosColors.disabledControlTextColor.darkColor,
      );
      bgColor = brightness.resolve(
        const Color(0xfff2f3f5),
        const Color(0xff3f4046),
      );
      borderColor = brightness.resolve(
        const Color(0xff979797),
        const Color(0xff222222),
      );
    } else {
      borderColor = brightness.resolve(
        const Color(0xffc3c4c9),
        const Color(0xff222222),
      );
      caretBgColor = MacosColors.controlColor
          .resolvedColor(context)
          .withValues(alpha: .05);
    }
    return _ButtonStyles(
      textColor: textColor,
      bgColor: bgColor,
      borderColor: borderColor,
      caretColor: caretColor,
      caretBgColor: caretBgColor,
    );
  }
}

class _ButtonStyles {
  _ButtonStyles({
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.caretColor,
    required this.caretBgColor,
  });

  Color textColor;
  Color bgColor;
  Color borderColor;
  Color caretColor;
  Color caretBgColor;
}

class _UpDownCaretsPainter extends CustomPainter {
  const _UpDownCaretsPainter({
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 4.0;
    final vPadding = size.height / 8 + 1.25;
    final hPadding = 2 * size.height / 8 + 1.25;

    // Draw background with border
    final bgPaint = Paint()..color = backgroundColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(radius),
    );

    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);

    // Draw carets
    final p1 = Offset(hPadding, size.height / 2 - 2.0);
    final p2 = Offset(size.width / 2, vPadding);
    final p4 = Offset(size.width - hPadding, size.height / 2 - 2.0);
    final p5 = Offset(hPadding, size.height / 2 + 2.0);
    final p6 = Offset(size.width / 2, size.height - vPadding);
    final p8 = Offset(size.width - hPadding, size.height / 2 + 2.0);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(p2, p4, paint);
    canvas.drawLine(p5, p6, paint);
    canvas.drawLine(p6, p8, paint);
  }

  @override
  bool shouldRepaint(_UpDownCaretsPainter oldDelegate) =>
      color != oldDelegate.color ||
      backgroundColor != oldDelegate.backgroundColor ||
      borderColor != oldDelegate.borderColor;

  @override
  bool shouldRebuildSemantics(_UpDownCaretsPainter oldDelegate) => false;
}

class NativeDropdownItem<T> {
  final String label;
  final T value;
  final bool enabled;
  final bool isDivider;

  const NativeDropdownItem({
    required this.label,
    required this.value,
    this.enabled = true,
    this.isDivider = false,
  });
}
