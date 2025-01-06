import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shakepin/app/misc/tools/tool.dart';
import 'package:shakepin/app/misc/tools/widgets/common_tool_widgets.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/logger.dart';

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
        final result = await Process.run('magick', [
          inputPath,
          '-define',
          'icon:auto-resize=16,32,48,64,128,256',
          outputPath,
        ]);

        if (result.exitCode != 0) {
          logger.log('Error converting to ICO: ${result.stderr}');
        } else {
          setState(() {
            _outputPath = outputPath;
          });
        }
      } catch (e) {
        logger.log('Error converting to ICO: $e');
      }
    }
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
        PushButton(
          controlSize: ControlSize.large,
          onPressed: _convertToIco,
          child: const Text('Convert to ICO'),
        ),
        if (_outputPath != null) ...[
          const SizedBox(height: 16),
          FilePathDisplay(
            label: 'Output File',
            filePath: _outputPath!,
          ),
        ],
      ],
    );
  }
}
