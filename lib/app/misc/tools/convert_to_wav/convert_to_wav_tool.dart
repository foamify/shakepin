import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/app/misc/tools/tool.dart';
import 'package:shakepin/app/misc/tools/widgets/common_tool_widgets.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';
import 'package:shakepin/utils/logger.dart';
import 'package:shakepin/widgets/double_slider.dart';

class ConvertToWavTool extends ToolWidget {
  const ConvertToWavTool({super.key});

  @override
  State<ConvertToWavTool> createState() => _ConvertToWavToolState();
}

class _ConvertToWavToolState extends State<ConvertToWavTool> {
  String? _outputPath;
  bool _isConverting = false;
  bool _enableTrim = false;
  Duration _startTime = Duration.zero;
  Duration? _endTime;
  Duration? _mediaDuration;
  String? _errorMessage;
  final Cli _cli = cli;

  @override
  void initState() {
    super.initState();
    _getMediaDuration();
  }

  @override
  void dispose() {
    _cli.dispose();
    super.dispose();
  }

  Future<void> _getMediaDuration() async {
    logger.log('[_getMediaDuration] Starting to get media duration');
    if (items().isEmpty) {
      logger.log('[_getMediaDuration] No items found, returning early');
      return;
    }

    try {
      logger.log(
          '[_getMediaDuration] Getting duration for file: ${items().first}');
      final duration = await _cli.getMediaDuration(items().first);
      logger.log('[_getMediaDuration] Received duration: $duration');
      if (duration != null) {
        setState(() {
          logger.log(
              '[_getMediaDuration] Updating state with duration: $duration');
          _mediaDuration = duration;
          _endTime = _mediaDuration;
        });
      } else {
        logger.log('[_getMediaDuration] Duration was null');
      }
    } catch (e) {
      logger.log('[_getMediaDuration] Error occurred: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    String milliseconds = twoDigits(duration.inMilliseconds.remainder(1000));
    return '$hours:$minutes:$seconds.$milliseconds';
  }

  Future<void> _convertToWav() async {
    logger.log('[_convertToWav] Starting conversion');
    if (items().isEmpty) {
      logger.log('[_convertToWav] No items to convert');
      return;
    }

    setState(() {
      _isConverting = true;
      _errorMessage = null;
    });

    final String inputPath = items().first;
    logger.log('[_convertToWav] Input path: $inputPath');

    if (outputDirectory.value == null) {
      logger.log('[_convertToWav] Loading output directory');
      await loadOutputDirectory();
    }

    if (outputDirectory.value != null) {
      final String outputPath = path.join(
        outputDirectory.value!,
        '${path.basenameWithoutExtension(inputPath)}_16k.wav',
      );
      logger.log('[_convertToWav] Output path: $outputPath');

      try {
        logger.log('[_convertToWav] Starting conversion process');
        logger.log('[_convertToWav] Trim enabled: $_enableTrim');
        if (_enableTrim) {
          logger.log('[_convertToWav] Start time: $_startTime');
          logger.log('[_convertToWav] End time: $_endTime');
        }

        await _cli.convertToWav(
          inputPath,
          startTime: _enableTrim ? _startTime : null,
          endTime: _enableTrim ? _endTime : null,
        );

        logger.log('[_convertToWav] Conversion completed successfully');
        setState(() {
          _outputPath = outputPath;
          _isConverting = false;
        });
      } catch (e) {
        logger.log('[_convertToWav] Error during conversion: $e');
        setState(() {
          _errorMessage = 'Error converting to WAV: $e';
          _isConverting = false;
        });
      }
    } else {
      logger.log('[_convertToWav] No output directory selected');
      setState(() {
        _errorMessage = 'No output directory selected';
        _isConverting = false;
      });
    }
  }

  Widget _buildTrimControls() {
    if (_mediaDuration == null) return const SizedBox.shrink();

    final endTime = _endTime ?? _mediaDuration!;
    if (endTime.inMilliseconds <= _startTime.inMilliseconds) {
      // Ensure end time is always greater than start time
      _endTime = Duration(milliseconds: _startTime.inMilliseconds + 1000);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_enableTrim && _mediaDuration != null) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: ${_formatDuration(_startTime)}',
                          style: const TextStyle(fontSize: 12)),
                      Text('To: ${_formatDuration(endTime)}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '${(_startTime.inMilliseconds / _mediaDuration!.inMilliseconds * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.systemGrey
                                  .resolveFrom(context))),
                      Text(
                          '${(endTime.inMilliseconds / _mediaDuration!.inMilliseconds * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.systemGrey
                                  .resolveFrom(context))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MacosDoubleSlider(
                startValue: _startTime.inMilliseconds.toDouble(),
                endValue: _endTime?.inMilliseconds.toDouble() ??
                    _mediaDuration!.inMilliseconds.toDouble(),
                min: 0,
                max: _mediaDuration!.inMilliseconds.toDouble(),
                onChanged: (startValue, endValue) {
                  setState(() {
                    _startTime = Duration(milliseconds: startValue.round());
                    _endTime = Duration(milliseconds: endValue.round());
                  });
                },
              )
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: CupertinoColors.systemRed.resolveFrom(context),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolContainer(
      children: [
        if (items().isNotEmpty) ...[
          FilePathDisplay(
            label: 'Selected File',
            filePath: items().first,
          ),
          const SizedBox(height: 16),
        ],
        if (_mediaDuration != null) ...[
          Row(
            children: [
              MacosCheckbox(
                value: _enableTrim,
                onChanged: (value) {
                  setState(() {
                    _enableTrim = value ?? false;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text('Trim audio'),
            ],
          ),
          const SizedBox(height: 16),
          if (_enableTrim) ...[
            _buildTrimControls(),
          ],
        ],
        PushButton(
          controlSize: ControlSize.large,
          onPressed: _isConverting ? null : _convertToWav,
          child: _isConverting
              ? const CupertinoActivityIndicator()
              : const Text('Convert to WAV'),
        ),
        if (_outputPath != null) ...[
          const SizedBox(height: 16),
          FilePathDisplay(
            label: 'Output File',
            filePath: _outputPath!,
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: CupertinoColors.systemRed),
          ),
        ],
      ],
    );
  }
}
