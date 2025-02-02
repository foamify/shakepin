part of '../cli.dart';

enum ArchiveFormat {
  zip('Zip', 0, 9),
  sevenZip('7z', 0, 9),
  tar('Tar', -1, -1); // tar doesn't support compression levels directly

  final String label;
  final int minCompressionLevel;
  final int maxCompressionLevel;

  const ArchiveFormat(
      this.label, this.minCompressionLevel, this.maxCompressionLevel);

  bool get supportsCompression => minCompressionLevel >= 0;

  String get extension {
    switch (this) {
      case ArchiveFormat.zip:
        return '.zip';
      case ArchiveFormat.sevenZip:
        return '.7z';
      case ArchiveFormat.tar:
        return '.tar.gz';
    }
  }

  int validateCompressionLevel(int level) {
    if (!supportsCompression) return 0;
    return level.clamp(minCompressionLevel, maxCompressionLevel);
  }
}

class EncryptionOptions {
  final String? password;
  final String? encryptionMethod; // AES-256, etc.

  const EncryptionOptions({
    this.password,
    this.encryptionMethod = 'AES-256',
  });
}

class _CliArchive {
  Future<String> _getUniqueArchiveName(
      String folder, ArchiveFormat format) async {
    String baseName = 'archive';
    String extension = format.extension;
    const int maxBaseLength = 200;

    // Ensure base name isn't too long
    if (baseName.length > maxBaseLength) {
      baseName = baseName.substring(0, maxBaseLength);
    }

    String fullPath = path.join(folder, '$baseName$extension');
    int counter = 1;

    while (await File(fullPath).exists()) {
      String newName = '$baseName (${counter++})';
      if (newName.length > maxBaseLength) {
        // Truncate the base name to make room for counter
        newName = '${baseName.substring(0, maxBaseLength - 5)} ($counter)';
      }
      fullPath = path.join(folder, '$newName$extension');
    }

    return fullPath;
  }

  Future<String?> archiveFiles(
    List<String> paths,
    String outputFolder, {
    void Function(double)? onProgress,
    void Function(String)? onFileProgress,
    required Future<ProcessResult> Function(String, List<String>,
            {bool noThrow})
        run,
    ArchiveFormat format = ArchiveFormat.zip,
    int compressionLevel = 6,
    EncryptionOptions? encryption,
  }) async {
    if (await dropChannel.isProcessRunning()) {
      logger.log('A process is already running. Please cancel it first.');
      return null;
    }
    final outputArchive = await _getUniqueArchiveName(outputFolder, format);
    final tempDir = await Directory(outputFolder).createTemp('archived');

    final validCompressionLevel =
        format.validateCompressionLevel(compressionLevel);

    try {
      // Total number of paths
      int totalPaths = paths.length;

      // Copy files to temporary directory
      for (int i = 0; i < totalPaths; i++) {
        final path = paths[i];
        final destPath = '${tempDir.path}/';

        if (onFileProgress != null) {
          onFileProgress(path);
        }

        // Use cp because ditto won't work for some reason
        await run('cp', [path, destPath]);

        // Calculate and update progress
        if (onProgress != null) {
          double progress =
              ((i + 1) / totalPaths) * 80; // First 80% for copying
          onProgress(progress);
        }
      }

      if (onFileProgress != null) {
        onFileProgress('Compressing...');
      }

      List<String> compressionArgs;
      switch (format) {
        case ArchiveFormat.zip:
          compressionArgs = [
            '-c',
            '-k',
            '--sequesterRsrc',
            if (format.supportsCompression)
              '--zlibCompressionLevel=$validCompressionLevel',
          ];
          if (encryption != null && encryption.password != null) {
            // Use zip with encryption
            return await _createEncryptedZip(
              tempDir.path,
              outputArchive,
              encryption.password!,
              validCompressionLevel,
              run,
            );
          }
          await run('ditto', [...compressionArgs, tempDir.path, outputArchive]);
          break;

        case ArchiveFormat.sevenZip:
          compressionArgs = ['a'];
          if (format.supportsCompression) {
            compressionArgs.add('-mx=$validCompressionLevel');
          }
          if (encryption != null && encryption.password != null) {
            compressionArgs.add('-p${encryption.password}');
          }
          await run('7zz', [...compressionArgs, outputArchive, tempDir.path]);
          break;

        case ArchiveFormat.tar:
          // For tar.gz, we'll use gzip's compression levels
          if (encryption != null && encryption.password != null) {
            await _createEncryptedTarGz(
              tempDir.path,
              outputArchive,
              encryption.password!,
              // validCompressionLevel,
              run,
            );
          } else {
            final gzipLevel = validCompressionLevel.clamp(1, 9);
            await run('tar', [
              '-czf',
              outputArchive,
              '-C',
              path.dirname(tempDir.path),
              path.basename(tempDir.path),
              '--options',
              'gzip:compression-level=$gzipLevel',
            ]);
          }
          break;
      }

      if (onProgress != null) {
        onProgress(100);
      }

      // Open Finder and reveal the archive
      await run('open', ['-R', outputArchive]);

      return outputArchive;
    } catch (e) {
      logger.log('Error during compression: $e');
      rethrow;
    } finally {
      // Clean up: remove the temporary directory
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        logger.log('Error deleting temporary directory: $e');
      }
    }
  }

  Future<String> _createEncryptedZip(
    String sourcePath,
    String outputPath,
    String password,
    int compressionLevel,
    Future<ProcessResult> Function(String, List<String>, {bool noThrow}) run,
  ) async {
    // Use zip with password protection
    await run(
        'zip',
        [
          '-r',
          '-P',
          password,
          '-$compressionLevel',
          outputPath,
          '.',
        ],
        noThrow: false);
    return outputPath;
  }

  Future<String> _createEncryptedTarGz(
    String sourcePath,
    String outputPath,
    String password,
    Future<ProcessResult> Function(String, List<String>, {bool noThrow}) run,
  ) async {
    // Create tar.gz and encrypt with OpenSSL
    final tempTar = '$outputPath.temp';

    // Create tar.gz first
    await run('tar', [
      '-czf',
      tempTar,
      '-C',
      path.dirname(sourcePath),
      path.basename(sourcePath),
    ]);

    if (password.isNotEmpty) {
      // Encrypt using OpenSSL (AES-256-CBC)
      await run('openssl', [
        'enc',
        '-aes-256-cbc',
        '-salt',
        '-pbkdf2', // Use PBKDF2 for key derivation (more secure)
        '-in',
        tempTar,
        '-out',
        outputPath,
        '-pass',
        'pass:$password',
      ]);
    }

    await File(tempTar).delete();
    return outputPath;
  }
}
