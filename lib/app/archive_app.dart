import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shakepin/utils/analytics.dart';
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
    dropChannel.setMinimumSize(AppSizes.archive);
    Analytics.archiveFiles();
    _initializeOutputFolder();
    super.initState();
  }

  var outputFolder = '';
  late Directory tempDir;
  var outputArchive = '';
  var files = <String>{};
  var currentlyProcessingFile = '';

  Future<void> _initializeOutputFolder() async {
    if (isAppStore) {
      final downloadsDir = await getDownloadsDirectory();
      outputFolder = downloadsDir?.path ?? '';
      if (files.isNotEmpty) {
        final paths = items();
        compressToZip(paths.toList());
      }
    } else {
      if (files.isNotEmpty) {
        final paths = items();
        final firstFilePath = paths.first;
        outputFolder = Directory(firstFilePath).parent.path;
        compressToZip(paths.toList());
      }
    }
  }

  Future<void> compressToZip(List<String> paths) async {
    outputArchive = await getUniqueArchiveName(outputFolder);

    try {
      tempDir = await Directory(outputFolder).createTemp('archived');

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
        outputArchive
      ]);

      if (result.exitCode != 0) {
        print('Error compressing files: ${result.stderr}');
        archiveProgress.value = -1;
      } else {
        archiveProgress.value = 100;
        if (archiveProgress() == 100) {
          Process.run('open', ['-R', outputArchive]);
        }
      }
    } catch (e) {
      print('Error during compression: $e');
      archiveProgress.value = -1;
    } finally {
      // Clean up: remove the temporary directory
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        print('Error deleting temporary directory: $e');
      }
    }

    setState(() {
      files = {};
    });
  }

  Future<String> getUniqueArchiveName(String folder) async {
    String baseName = 'archive';
    String extension = '.zip';
    String fullPath = '$folder/$baseName$extension';
    int counter = 1;

    while (await File(fullPath).exists()) {
      fullPath = '$folder/$baseName (${counter++})$extension';
    }

    return fullPath;
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
                                  text: 'Archived ${items().length} files to '),
                              TextSpan(
                                text: outputArchive,
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
                          // Delete the archive file and temp dir if cancel
                          try {
                            await File(outputArchive).delete();
                          } catch (e) {
                            print('Error deleting output archive: $e');
                          }
                          try {
                            await tempDir.delete(recursive: true);
                          } catch (e) {
                            print('Error deleting output folder: $e');
                          }
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
