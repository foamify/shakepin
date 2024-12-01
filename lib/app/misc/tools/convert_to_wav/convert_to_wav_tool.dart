import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/app/misc/tools/tool.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/cli.dart';

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
    print('[_getMediaDuration] Starting to get media duration');
    if (items().isEmpty) {
      print('[_getMediaDuration] No items found, returning early');
      return;
    }

    try {
      print('[_getMediaDuration] Getting duration for file: ${items().first}');
      final duration = await _cli.getMediaDuration(items().first);
      print('[_getMediaDuration] Received duration: $duration');
      if (duration != null) {
        setState(() {
          print('[_getMediaDuration] Updating state with duration: $duration');
          _mediaDuration = duration;
          _endTime = _mediaDuration;
        });
      } else {
        print('[_getMediaDuration] Duration was null');
      }
    } catch (e) {
      print('[_getMediaDuration] Error occurred: $e');
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
    return '$hours:$minutes:$seconds';
  }

  Future<void> _convertToWav() async {
    print('[_convertToWav] Starting conversion');
    if (items().isEmpty) {
      print('[_convertToWav] No items to convert');
      return;
    }

    setState(() {
      _isConverting = true;
      _errorMessage = null;
    });

    final String inputPath = items().first;
    print('[_convertToWav] Input path: $inputPath');

    if (outputDirectory.value == null) {
      print('[_convertToWav] Loading output directory');
      await loadOutputDirectory();
    }

    if (outputDirectory.value != null) {
      final String outputPath = path.join(
        outputDirectory.value!,
        '${path.basenameWithoutExtension(inputPath)}_16k.wav',
      );
      print('[_convertToWav] Output path: $outputPath');

      try {
        print('[_convertToWav] Starting conversion process');
        print('[_convertToWav] Trim enabled: $_enableTrim');
        if (_enableTrim) {
          print('[_convertToWav] Start time: $_startTime');
          print('[_convertToWav] End time: $_endTime');
        }

        await _cli.convertToWav(
          inputPath,
          outputPath,
          startTime: _enableTrim ? _startTime : null,
          endTime: _enableTrim ? _endTime : null,
        );

        print('[_convertToWav] Conversion completed successfully');
        setState(() {
          _outputPath = outputPath;
          _isConverting = false;
        });
      } catch (e) {
        print('[_convertToWav] Error during conversion: $e');
        setState(() {
          _errorMessage = 'Error converting to WAV: $e';
          _isConverting = false;
        });
      }
    } else {
      print('[_convertToWav] No output directory selected');
      setState(() {
        _errorMessage = 'No output directory selected';
        _isConverting = false;
      });
    }
  }

  Widget _buildTrimControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MacosCheckbox(
              value: _enableTrim,
              onChanged: (value) {
                setState(() {
                  _enableTrim = value;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(width: 8),
            const Text('Trim audio'),
          ],
        ),
        if (_enableTrim && _mediaDuration != null) ...[
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Start: ${_formatDuration(_startTime)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${(_startTime.inMilliseconds / _mediaDuration!.inMilliseconds * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MacosSlider(
                value: _startTime.inMilliseconds.toDouble(),
                min: 0,
                max: (_endTime ?? _mediaDuration!).inMilliseconds.toDouble(),
                onChanged: (value) {
                  setState(() {
                    _startTime = Duration(milliseconds: value.round());
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'End: ${_formatDuration(_endTime ?? _mediaDuration!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${((_endTime ?? _mediaDuration!).inMilliseconds / _mediaDuration!.inMilliseconds * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MacosSlider(
                value: (_endTime ?? _mediaDuration!).inMilliseconds.toDouble(),
                min: _startTime.inMilliseconds.toDouble(),
                max: _mediaDuration!.inMilliseconds.toDouble(),
                onChanged: (value) {
                  setState(() {
                    _endTime = Duration(milliseconds: value.round());
                  });
                },
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: CupertinoColors.systemGrey.withOpacity(.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items().isNotEmpty) ...[
                const Text(
                  'Selected File',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    items().first,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildTrimControls(),
              const SizedBox(height: 16),
              PushButton(
                controlSize: ControlSize.large,
                onPressed: _isConverting ? null : _convertToWav,
                child: _isConverting
                    ? const ProgressCircle(radius: 8)
                    : const Text('Convert to 16kHz WAV'),
              ),
              if (_outputPath != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Output File',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _outputPath!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                PushButton(
                  controlSize: ControlSize.regular,
                  onPressed: () {
                    Process.run('open', ['-R', _outputPath!]);
                  },
                  child: const Text('Show in Finder'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
