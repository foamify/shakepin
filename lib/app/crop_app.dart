import 'dart:ui';
import 'dart:io';

import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shakepin/widgets/glass_button.dart';
import 'package:shakepin/app/sections/minify_section/minify_state.dart';
import 'package:shakepin/widgets/native_dropdown_button.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:shakepin/widgets/native_tooltip.dart';
import 'package:video_player/video_player.dart';

class CropOverlayPainter extends CustomPainter {
  final Rect hole;

  CropOverlayPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          Colors.black.withValues(alpha: 0.5) // Changed from withAlpha(128)
      ..style = PaintingStyle.fill;

    // Create a path for the entire canvas
    final path = Path()..addRect(Offset.zero & size);

    // Subtract the hole
    path.addRect(hole);

    // Use even-odd fill type to create the hole
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) =>
      hole != oldDelegate.hole;
}

class CropApp extends StatefulWidget {
  const CropApp({super.key});

  @override
  State<CropApp> createState() => _CropAppState();
}

class _CropAppState extends State<CropApp> {
  final _leftController = TextEditingController(text: '0');
  final _rightController = TextEditingController(text: '0');
  final _topController = TextEditingController(text: '0');
  final _bottomController = TextEditingController(text: '0');
  String? _selectedImage;

  Image? _currentImage;
  Size? _imageSize;

  // Change to store deep copy of crop data
  Map<String, CropValues>? _initialCropData;

  // Add new state variables for multiple image support
  List<String> _imagesToCrop = [];
  int _currentIndex = 0;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    isCropApp.addListener(_handleCropAppVisibility);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _handleCropAppVisibility() {
    if (isCropApp.value) {
      // Initialize list of images and videos when crop app opens
      _imagesToCrop = selectedItems()
          .where((path) => isImageFile(path) || isVideoFile(path))
          .toList();
      _currentIndex = 0;
      _initializeSelectedImage();
    }
  }

  void _initializeSelectedImage() {
    if (_imagesToCrop.isNotEmpty) {
      _selectedImage = _imagesToCrop[_currentIndex];

      // Create deep copy of initial crop data
      _initialCropData = {};
      for (final entry in cropData().entries) {
        _initialCropData![entry.key] = CropValues(
          left: entry.value.left,
          right: entry.value.right,
          top: entry.value.top,
          bottom: entry.value.bottom,
          width: entry.value.width,
          height: entry.value.height,
        );
      }

      // Load existing crop data or reset to 0
      if (cropData().containsKey(_selectedImage)) {
        final data = cropData()[_selectedImage!]!;
        _leftController.text = data.left.toString();
        _rightController.text = data.right.toString();
        _topController.text = data.top.toString();
        _bottomController.text = data.bottom.toString();
      } else {
        _leftController.text = '0';
        _rightController.text = '0';
        _topController.text = '0';
        _bottomController.text = '0';
      }
      _loadImage();
    }
  }

  void _loadImage() {
    if (_selectedImage != null) {
      final file = File(_selectedImage!);
      if (file.existsSync()) {
        // Reset video state when switching media
        if (!isVideoFile(_selectedImage!)) {
          _videoController?.dispose();
          _videoController = null;
          _isVideoInitialized = false;

          _currentImage = Image.file(file);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _currentImage!.image
                .resolve(const ImageConfiguration())
                .addListener(
              ImageStreamListener((info, _) {
                setState(() {
                  _imageSize = Size(
                    info.image.width.toDouble(),
                    info.image.height.toDouble(),
                  );
                });
              }),
            );
          });
        } else {
          // Clear image when switching to video
          _currentImage = null;
          _videoController = VideoPlayerController.file(file)
            ..initialize().then((_) {
              if (mounted) {
                setState(() {
                  _isVideoInitialized = true;
                  _imageSize = Size(
                    _videoController!.value.size.width,
                    _videoController!.value.size.height,
                  );
                });
                _videoController!.pause();
              }
            });
        }
      }
    }
  }

  String _getCroppedDimensions() {
    if (_imageSize == null) return '';
    final left = int.tryParse(_leftController.text) ?? 0;
    final right = int.tryParse(_rightController.text) ?? 0;
    final top = int.tryParse(_topController.text) ?? 0;
    final bottom = int.tryParse(_bottomController.text) ?? 0;

    final width = _imageSize!.width.toInt() - left - right;
    final height = _imageSize!.height.toInt() - top - bottom;

    return '$width×$height';
  }

  int _getMaxValue(String label, int value) {
    if (_imageSize == null) return value;
    final width = _imageSize!.width.toInt();
    final height = _imageSize!.height.toInt();

    // Get current values for all margins
    final left = int.tryParse(_leftController.text) ?? 0;
    final right = int.tryParse(_rightController.text) ?? 0;
    final top = int.tryParse(_topController.text) ?? 0;
    final bottom = int.tryParse(_bottomController.text) ?? 0;

    return switch (label) {
      'Left' => width - right - 1, // Leave at least 1px width
      'Right' => width - left - 1, // Leave at least 1px width
      'Top' => height - bottom - 1, // Leave at least 1px height
      'Bottom' => height - top - 1, // Leave at least 1px height
      _ => value,
    };
  }

  void _handleNext() {
    if (_currentIndex < _imagesToCrop.length - 1) {
      _currentIndex++;
      _initializeSelectedImage();
    }
  }

  void _handlePrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _initializeSelectedImage();
    }
  }

  Widget _buildVideoControls() {
    if (_videoController == null || !_isVideoInitialized)
      return const SizedBox();

    return Row(
      spacing: 8,
      children: [
        ValueListenableBuilder(
          valueListenable: _videoController!,
          builder: (context, value, child) {
            return GlassButton(
              ghost: true,
              radius: 6,
              padding: const EdgeInsets.all(4),
              onTap: () {
                if (value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              },
              child: Icon(
                value.isPlaying
                    ? FluentIcons.pause_12_filled
                    : FluentIcons.play_12_filled,
                size: 16,
              ),
            );
          },
        ),
        // Video progress slider
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: _videoController!,
            builder: (context, value, child) {
              return MacosSlider(
                value: value.position.inMilliseconds.toDouble(),
                min: 0,
                max: value.duration.inMilliseconds.toDouble(),
                onChanged: (newValue) {
                  _videoController!
                      .seekTo(Duration(milliseconds: newValue.round()));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: isCropApp,
      builder: (context, _) {
        return MacosScaffold(
          children: [
            ContentArea(
              builder: (context, scrollController) {
                return Stack(
                  children: [
                    // Main content area with image preview
                    Column(
                      children: [
                        const SizedBox(
                          height: 36,
                        ),
                        if ((_currentImage != null || _isVideoInitialized) &&
                            _imageSize != null)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ListenableBuilder(
                                    listenable: Listenable.merge([
                                      _leftController,
                                      _rightController,
                                      _topController,
                                      _bottomController,
                                    ]),
                                    builder: (context, _) {
                                      return Stack(
                                        children: [
                                          // Show either video or image
                                          if (_videoController != null &&
                                              _isVideoInitialized)
                                            AspectRatio(
                                              aspectRatio: _videoController!
                                                  .value.aspectRatio,
                                              child: VideoPlayer(
                                                  _videoController!),
                                            )
                                          else if (_currentImage != null)
                                            _currentImage!,

                                          // Gray overlay with hole
                                          Positioned.fill(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                final scale =
                                                    constraints.maxWidth /
                                                        _imageSize!.width;
                                                final left = (double.tryParse(
                                                            _leftController
                                                                .text) ??
                                                        0.0) *
                                                    scale;
                                                final top = (double.tryParse(
                                                            _topController
                                                                .text) ??
                                                        0.0) *
                                                    scale;
                                                final right = (double.tryParse(
                                                            _rightController
                                                                .text) ??
                                                        0.0) *
                                                    scale;
                                                final bottom = (double.tryParse(
                                                            _bottomController
                                                                .text) ??
                                                        0.0) *
                                                    scale;

                                                return CustomPaint(
                                                  painter: CropOverlayPainter(
                                                    hole: Rect.fromLTRB(
                                                      left,
                                                      top,
                                                      constraints.maxWidth -
                                                          right,
                                                      constraints.maxHeight -
                                                          bottom,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),

                                          // Scaled crop overlay (dotted border)
                                          Positioned.fill(
                                            child: LayoutBuilder(builder:
                                                (context, constraints) {
                                              final scale =
                                                  constraints.maxWidth /
                                                      _imageSize!.width;
                                              return Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  (double.tryParse(
                                                              _leftController
                                                                  .text) ??
                                                          0.0) *
                                                      scale,
                                                  (double.tryParse(
                                                              _topController
                                                                  .text) ??
                                                          0.0) *
                                                      scale,
                                                  (double.tryParse(
                                                              _rightController
                                                                  .text) ??
                                                          0.0) *
                                                      scale,
                                                  (double.tryParse(
                                                              _bottomController
                                                                  .text) ??
                                                          0.0) *
                                                      scale,
                                                ),
                                                child: DottedBorder(
                                                  color: MacosColors
                                                      .systemBlueColor,
                                                  strokeWidth: 2,
                                                  borderType: BorderType.Rect,
                                                  dashPattern: const [6, 4],
                                                  child:
                                                      const SizedBox.expand(),
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                      );
                                    }),
                              ),
                            ),
                          )
                        else
                          const Center(
                            child: Text('Select an image to crop'),
                          ),
                        _buildBottomControls(context),
                      ],
                    ),

                    // Draggable top area
                    Positioned(
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
                    ),

                    // Close button
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _buildCloseButton(context),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(8).copyWith(topLeft: const Radius.circular(32)),
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
          onPressed: _handleCloseButtonPress,
          backgroundColor: CupertinoColors.label
              .resolveFrom(context)
              .withValues(alpha: 0.5), // Changed from withAlpha(128)
          hoverColor: CupertinoColors.label
              .resolveFrom(context)
              .withValues(alpha: 0.9), // Changed from withAlpha(230)
          pressedOpacity: .6,
          icon: Icon(
            FluentIcons.dismiss_24_filled,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            size: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(8),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MacosColors.controlBackgroundColor
                .withValues(alpha: 0.1), // Changed from withAlpha(25)
            border: Border(
              top: BorderSide(
                color: MacosTheme.brightnessOf(context).isDark
                    ? Colors.white
                        .withValues(alpha: 0.1) // Changed from withAlpha(25)
                    : Colors.black
                        .withValues(alpha: 0.1), // Changed from withAlpha(25)
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add navigation controls
              if (_imagesToCrop.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlassButton(
                        onTap: _currentIndex > 0 ? _handlePrevious : null,
                        child: const Text('Previous'),
                      ),
                      const SizedBox(width: 8),
                      Text('${_currentIndex + 1} / ${_imagesToCrop.length}'),
                      const SizedBox(width: 8),
                      GlassButton(
                        onTap: _currentIndex < _imagesToCrop.length - 1
                            ? _handleNext
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              AnimatedSize(
                duration: Durations.long1,
                curve: Curves.fastEaseInToSlowEaseOut,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_videoController != null && _isVideoInitialized) ...[
                        const SizedBox(height: 8),
                        _buildVideoControls(),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              if (_selectedImage != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Media: '),
                    NativeTooltip(
                      message: _selectedImage!,
                      child: Text(
                        _selectedImage!.split('/').last,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Image dimensions info
                if (_imageSize != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Text('Dimensions: '),
                        Text(
                          '${_imageSize!.width.toInt()}×${_imageSize!.height.toInt()}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Text(' → '),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            _leftController,
                            _rightController,
                            _topController,
                            _bottomController,
                          ]),
                          builder: (context, child) {
                            return Text(
                              _getCroppedDimensions(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: MacosColors.systemBlueColor,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                // Crop controls
                Row(
                  children: [
                    _buildCropField('Left', _leftController),
                    _buildCropField('Right', _rightController),
                    _buildCropField('Top', _topController),
                    _buildCropField('Bottom', _bottomController),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassButton(
                    secondary: true,
                    onTap: _handleCloseButtonPress,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    onTap: _handleApplyButtonPress,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropField(String label, TextEditingController controller) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: PointerLockDragArea(
                cursor: PointerLockCursor.normal,
                onMove: (details) {
                  final currentValue = int.tryParse(controller.text) ?? 0;
                  final delta = details.move.delta.dx.round();
                  final newValue = currentValue + delta;

                  final clampedValue =
                      newValue.clamp(0, _getMaxValue(label, newValue));

                  if (clampedValue != currentValue) {
                    controller.text = clampedValue.toString();
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                    _updateCropData();
                  }
                },
                child: Text(label),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  final currentValue = int.tryParse(controller.text) ?? 0;
                  final delta = details.delta.dx.round();
                  final newValue = currentValue + delta;

                  final clampedValue =
                      newValue.clamp(0, _getMaxValue(label, newValue));

                  if (clampedValue != currentValue) {
                    controller.text = clampedValue.toString();
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                    _updateCropData();
                  }
                },
                child: MacosTextField(
                  controller: controller,
                  placeholder: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final intValue = int.tryParse(value) ?? 0;
                    final clampedValue =
                        intValue.clamp(0, _getMaxValue(label, intValue));
                    if (clampedValue != intValue) {
                      controller.text = clampedValue.toString();
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                    }
                    _updateCropData();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateCropData() {
    if (_selectedImage != null && _imageSize != null) {
      cropData.value = {
        ...cropData(),
        _selectedImage!: CropValues(
          left: int.tryParse(_leftController.text) ?? 0,
          right: int.tryParse(_rightController.text) ?? 0,
          top: int.tryParse(_topController.text) ?? 0,
          bottom: int.tryParse(_bottomController.text) ?? 0,
          width: _imageSize!.width.toInt(),
          height: _imageSize!.height.toInt(),
        ),
      };
    }
  }

  Future<void> _handleCloseButtonPress() async {
    if (_initialCropData != null) {
      print('Restoring initial crop data: $_initialCropData');
      // Restore the initial state
      cropData.value = Map.from(_initialCropData!);
    } else {
      print('Crop data not changed');
    }
    _initialCropData = null; // Clear the temporary storage
    isCropApp.value = false;
    showApp();
  }

  Future<void> _handleApplyButtonPress() async {
    if (_selectedImage == null || _imageSize == null) return;
    _updateCropData(); // Ensure final state is saved
    _initialCropData = null; // Clear temporary storage
    isCropApp.value = false;
    showApp();
  }
}
