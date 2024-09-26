import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:shakepin/utils/drop_channel.dart';

import '../state.dart';
import '../utils/utils.dart';

class ArchiveApp extends StatefulWidget {
  const ArchiveApp({super.key});

  @override
  State<ArchiveApp> createState() => _ArchiveAppState();
}

class _ArchiveAppState extends State<ArchiveApp> {
  @override
  void initState() {
    files = items();
    DropChannel.setMinimumSize(AppSizes.archive);
    if (files.isNotEmpty) {
      final firstFilePath = files.first;
      final firstFileDir = Directory(File(firstFilePath).parent.path);
      outputFolder = firstFileDir.path;
      final paths = items();
      compressToZip(paths.toList());
    }
    super.initState();
  }

  var outputFolder = '';
  var files = <String>{};
  var currentlyProcessingFile = '';

  Future<void> compressToZip(List<String> paths) async {
    final outputFile = '$outputFolder/archive.zip';
    final tempDir = await Directory(outputFolder).createTemp('archived');

    try {
      // Total number of paths
      int totalPaths = paths.length;

      // Copy files to temporary directory
      for (int i = 0; i < totalPaths; i++) {
        if (archiveProgress() == -1) {
          print('Compression cancelled');
          return;
        }

        final path = paths[i];
        final destPath = '${tempDir.path}/';

        setState(() {
          currentlyProcessingFile = path;
        });

        // Use cp because ditto won't work for some reason
        await Process.run('cp', [path, destPath]);

        // Calculate and update progress
        double progress = ((i + 1) / totalPaths) * 80; // First 50% for copying
        archiveProgress.value = progress;
      }

      // Compress the temporary directory
      final result = await Process.run('ditto', [
        '-c',
        '-k',
        '--sequesterRsrc',
        '--zlibCompressionLevel=9',
        tempDir.path,
        outputFile
      ]);

      if (result.exitCode != 0) {
        print('Error compressing files: ${result.stderr}');
        archiveProgress.value = -1;
      } else {
        archiveProgress.value = 100;
        if (archiveProgress() == 100) {
          Process.run('open', [outputFolder]);
        }
      }
    } finally {
      // Clean up: remove the temporary directory
      await tempDir.delete(recursive: true);
    }

    items.value = {};
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: archiveProgress,
      builder: (context, progress, child) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox.fromSize(
            size: AppSizes.archive,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    progress != 100 ? 'Archiving Files' : 'Archiving Complete',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (progress != 100) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ProgressBar(
                            value: progress,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (progress != 80)
                      FutureBuilder<int>(
                        future: File(currentlyProcessingFile).length(),
                        builder: (context, snapshot) {
                          final fileSize = snapshot.hasData
                              ? '(${formatFileSize(snapshot.data!)})'
                              : '';
                          return Text(
                            '$currentlyProcessingFile $fileSize',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      )
                    else
                      const Text('Compressing...')
                  ] else
                    FutureBuilder<int>(
                      future: File('$outputFolder/archive.zip').length(),
                      builder: (context, snapshot) {
                        final archiveSize = snapshot.hasData
                            ? '(${formatFileSize(snapshot.data!)})'
                            : '';
                        return Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                  text: 'Archived ${files.length} files to '),
                              TextSpan(
                                text: outputFolder,
                                style: const TextStyle(
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  color: Colors.blue,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Process.run('open', [outputFolder]);
                                  },
                              ),
                              TextSpan(
                                text: ' $archiveSize',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  // const SizedBox(height: 20),
                  // if (progress == 100) ...[
                  //   const Text(
                  //     'Revealing archive in Finder...',
                  //     style: TextStyle(fontSize: 12),
                  //   ),
                  //   const SizedBox(height: 20),
                  // ],
                  const Spacer(),
                  SizedBox(
                    width: 100,
                    child: PushButton(
                      controlSize: ControlSize.regular,
                      onPressed: () async {
                        archiveProgress.value = -1;
                        items.value = {};
                        if (progress != 100) {
                          // Delete the archive file if cancel

                          await Directory(outputFolder).delete(recursive: true);
                        }
                      },
                      color: progress != 100
                          ? CupertinoColors.destructiveRed
                          : null,
                      child: Text(
                        progress != 100 ? 'Cancel' : 'Close',
                        style: TextStyle(
                          color: progress != 100 ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
