import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/app/misc/tools/tool.dart';
import 'package:shakepin/state.dart';

class ConvertToIcoTool extends ToolWidget {
  const ConvertToIcoTool({super.key});

  @override
  State<ConvertToIcoTool> createState() => _ConvertToIcoToolState();
}

class _ConvertToIcoToolState extends State<ConvertToIcoTool> {
  String? _outputPath;

  Future<void> _convertToIco() async {
    if (items().isEmpty) return;

    final String inputPath = items().first;
    if (outputDirectory.value == null) {
      await loadOutputDirectory();
    }

    if (outputDirectory.value != null) {
      final String outputPath = path.join(
        outputDirectory.value!,
        '${path.basenameWithoutExtension(inputPath)}.ico',
      );

      try {
        final result = await Process.run(imageMagickPath, [
          'convert',
          inputPath,
          '-define',
          'icon:auto-resize=16,32,48,64,128,256',
          outputPath,
        ]);

        if (result.exitCode != 0) {
          print('Error converting to ICO: ${result.stderr}');
        } else {
          setState(() {
            _outputPath = outputPath;
          });
        }
      } catch (e) {
        print('Error converting to ICO: $e');
      }
    }
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
                  child: SelectableText(
                    items().first,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              PushButton(
                controlSize: ControlSize.large,
                onPressed: _convertToIco,
                child: const Text('Convert to ICO'),
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
              ],
            ],
          ),
        ),
      ],
    );
  }
}
