import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/app/misc/tools/tool.dart';
import 'package:shakepin/state.dart';

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

  @override
  void initState() {
    super.initState();
    _getMediaDuration();
  }

  Future<void> _getMediaDuration() async {
    if (items().isEmpty) return;

    try {
      final result = await Process.run(ffmpegPath, [
        '-i',
        items().first,
        '-show_entries',
        'format=duration',
        '-v',
        'quiet',
        '-of',
        'csv=p=0',
      ]);

      if (result.exitCode == 0) {
        final duration = double.tryParse(result.stdout.toString().trim());
        if (duration != null) {
          setState(() {
            _mediaDuration = Duration(milliseconds: (duration * 1000).round());
            _endTime = _mediaDuration;
          });
        }
      }
    } catch (e) {
      print('Error getting media duration: $e');
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
    if (items().isEmpty) return;

    setState(() {
      _isConverting = true;
      _errorMessage = null;
    });

    final String inputPath = items().first;
    if (outputDirectory.value == null) {
      await loadOutputDirectory();
    }

    if (outputDirectory.value != null) {
      final String outputPath = path.join(
        outputDirectory.value!,
        '${path.basenameWithoutExtension(inputPath)}_16k.wav',
      );

      try {
        List<String> ffmpegArgs = [
          '-i',
          inputPath,
        ];

        if (_enableTrim) {
          ffmpegArgs.addAll(['-ss', _formatDuration(_startTime)]);
          if (_endTime != null) {
            ffmpegArgs.addAll(['-to', _formatDuration(_endTime!)]);
          }
        }

        ffmpegArgs.addAll([
          '-acodec',
          'pcm_s16le',
          '-ar',
          '16000',
          '-ac',
          '1',
          '-y',
          outputPath,
        ]);

        final result = await Process.run(ffmpegPath, ffmpegArgs);

        if (result.exitCode != 0) {
          setState(() {
            _errorMessage = 'Error converting to WAV: ${result.stderr}';
          });
          print('Error converting to WAV: ${result.stderr}');
        } else {
          setState(() {
            _outputPath = outputPath;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error converting to WAV: $e';
        });
        print('Error converting to WAV: $e');
      } finally {
        setState(() {
          _isConverting = false;
        });
      }
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
            border: Border.all(color: CupertinoColors.systemGrey.withOpacity(.2)),
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
