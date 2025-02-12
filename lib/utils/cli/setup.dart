part of '../cli.dart';

class _CliSetup {
  bool get isWindows => Platform.isWindows;

  Future<void> setup({
    required Function(SetupStep step) onProgress,
    required Function(String error, SetupStep step) onError,
    required Function() onSuccess,
    required Future<ProcessResult> Function(String, List<String>,
            {bool noThrow})
        run,
  }) async {
    logger.log('[_CliSetup] Starting setup...');
    final stopwatch = Stopwatch()..start();

    void updateProgress(SetupStep step) {
      logger.log('[_CliSetup] Progress: ${step.label} (${step.progress})');
      onProgress(step);
    }

    try {
      if (isWindows) {
        await _setupWindows(updateProgress, onError, onSuccess, run);
      } else {
        await _setupMacOS(updateProgress, onError, onSuccess, run);
      }

      updateProgress(SetupStep.finishingUp);
      stopwatch.stop();
      logger.log(
          '[_CliSetup] Setup completed in ${stopwatch.elapsed.inSeconds}s');
      onSuccess();
    } catch (e) {
      logger.log('[_CliSetup] Error: $e');
      onError(e.toString(), setupStep.value ?? SetupStep.checkingHomebrew);
    }
  }

  Future<void> _setupWindows(
    Function(SetupStep) updateProgress,
    Function(String, SetupStep) onError,
    Function() onSuccess,
    Future<ProcessResult> Function(String, List<String>, {bool noThrow}) run,
  ) async {
    Future<bool> checkCommandExists(String command, {List<String>? altPaths}) async {
      try {
        // Try normal PATH first
        var result = await Process.run('where.exe', [command], runInShell: true);
        if (result.exitCode == 0) return true;

        // Check alternative paths if provided
        if (altPaths != null) {
          for (final path in altPaths) {
            final fullPath = '$path\\$command';
            if (await File(fullPath).exists()) {
              // Add to PATH if found
              final currentPath = Platform.environment['PATH'] ?? '';
              final pathCmd = 'setx PATH "$path;$currentPath"';
              await Process.run('cmd', ['/c', pathCmd], runInShell: true);
              return true;
            }
          }
        }
        return false;
      } catch (e) {
        return false;
      }
    }

    Future<bool> acceptSourceAgreements() async {
      try {
        final result = await Process.run(
          'winget',
          ['source', 'reset', '--force'],
          runInShell: true,
        );
        return result.exitCode == 0;
      } catch (e) {
        return false;
      }
    }

    SetupStep getCheckingStep(String command) {
      final toolName = command.toLowerCase().replaceAll('.exe', '');
      if (toolName.contains('7z')) return SetupStep.checkingSevenZip;
      if (toolName.contains('ffmpeg')) return SetupStep.checkingFfmpeg;
      if (toolName.contains('magick')) return SetupStep.checkingImageMagick;
      if (toolName.contains('yt-dlp')) return SetupStep.checkingYtDlp;
      if (toolName.contains('gallery-dl')) return SetupStep.checkingGalleryDl;
      if (toolName.contains('gifski')) return SetupStep.checkingGifski;
      throw Exception('Unknown tool: $command');
    }

    SetupStep getInstallingStep(String command) {
      final toolName = command.toLowerCase().replaceAll('.exe', '');
      if (toolName.contains('7z')) return SetupStep.installingSevenZip;
      if (toolName.contains('ffmpeg')) return SetupStep.installingFfmpeg;
      if (toolName.contains('magick')) return SetupStep.installingImageMagick;
      if (toolName.contains('yt-dlp')) return SetupStep.installingYtDlp;
      if (toolName.contains('gallery-dl')) return SetupStep.installingGalleryDl;
      if (toolName.contains('gifski')) return SetupStep.installingGifski;
      throw Exception('Unknown tool: $command');
    }

    Future<bool> installPackage(String packageId, String command) async {
      // First try to install silently
      var installResult = await Process.run(
        'winget',
        ['install', '--silent', '--exact', '--id', packageId],
        runInShell: true,
      );
      
      final output = '${installResult.stdout}\n${installResult.stderr}'.toLowerCase();
      
      // Check if package is already installed - this is actually a success case
      if (output.contains('already installed') || 
          output.contains('no available upgrade found')) {
        return true;
      }
      
      // If silent install fails, try interactive
      if (installResult.exitCode != 0) {
        installResult = await Process.run(
          'winget',
          ['install', '--exact', '--id', packageId],
          runInShell: true,
        );
        
        // Check again for successful installation
        if (installResult.exitCode == 0 || 
            output.contains('already installed') ||
            output.contains('no available upgrade found')) {
          return true;
        }
      }
      
      return false;
    }

    try {
      // Check winget
      updateProgress(SetupStep.checkingPackageManager);
      if (!await checkCommandExists('winget')) {
        onError(
            'Winget not found. Please install the latest Windows App Installer from the Microsoft Store.',
            SetupStep.checkingPackageManager);
        return;
      }

      // Accept source agreements first
      await acceptSourceAgreements();

      // Windows tool mappings (package-id : command-to-check : alternative paths)
      final toolsToInstall = {
        '7zip.7zip': (
          '7z.exe',
          [
            'C:\\Program Files\\7-Zip',
            'C:\\Program Files (x86)\\7-Zip',
          ]
        ),
        'GyanD.FFmpeg': (
          'ffmpeg.exe',
          [
            'C:\\ffmpeg\\bin',
          ]
        ),
        'ImageMagick.ImageMagick': (
          'magick.exe',
          [
            'C:\\Program Files\\ImageMagick-7.0.11-Q16',
            'C:\\Program Files\\ImageMagick*',
          ]
        ),
        'yt-dlp.yt-dlp': (
          'yt-dlp.exe',
          [
            'C:\\Users\\${Platform.environment['USERNAME']}\\AppData\\Local\\Microsoft\\WinGet\\Packages',
          ]
        ),
        'mikf.gallery-dl': (
          'gallery-dl.exe',
          [
            'C:\\Users\\${Platform.environment['USERNAME']}\\AppData\\Local\\Programs\\gallery-dl',
          ]
        ),
        // '???': (
        //   'gifski.exe',
        //   [
        //     'C:\\Users\\${Platform.environment['USERNAME']}\\AppData\\Local\\Microsoft\\WinGet\\Packages',
        //   ]
        // ),
      };

      for (final entry in toolsToInstall.entries) {
        final packageId = entry.key;
        final command = entry.value.$1;
        final altPaths = entry.value.$2;
        
        final checkingStep = getCheckingStep(command);
        updateProgress(checkingStep);
        
        if (!await checkCommandExists(command, altPaths: altPaths)) {
          final installingStep = getInstallingStep(command);
          updateProgress(installingStep);
              
          if (!await installPackage(packageId, command)) {
            onError(
              'Failed to install $packageId. Please try installing manually: winget install --id $packageId', 
              installingStep
            );
            return;
          }
          
          // Verify installation with alternative paths
          if (!await checkCommandExists(command, altPaths: altPaths)) {
            onError(
              'Installation completed but command $command not found. Please ensure the program is installed and try restarting the application.',
              installingStep
            );
            return;
          }
        }
      }

      onSuccess();
    } catch (e) {
      logger.log('[_CliSetup] Error: $e');
      onError(e.toString(), setupStep.value ?? SetupStep.checkingPackageManager);
    }
  }

  Future<void> _setupMacOS(
    Function(SetupStep) onProgress,
    Function(String, SetupStep) onError,
    Function() onSuccess,
    Future<ProcessResult> Function(String, List<String>, {bool noThrow}) run,
  ) async {
    logger.log('[_CliSetup] Starting setup...');
    final stopwatch = Stopwatch()..start();

    void updateProgress(SetupStep step) {
      logger.log('[_CliSetup] Progress: ${step.label} (${step.progress})');
      onProgress(step);
    }

    try {
      // Check Homebrew
      updateProgress(SetupStep.checkingHomebrew);
      final brewResult = await run('which', ['brew'], noThrow: true);
      if (brewResult.exitCode != 0) {
        updateProgress(SetupStep.installingHomebrew);
        const installScript =
            'yes \'\' | /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"';
        final result = await run(installScript, [], noThrow: true);
        if (result.exitCode != 0) {
          onError('Failed to install Homebrew: ${result.stderr}',
              SetupStep.installingHomebrew);
          return;
        }
      }
      updateProgress(SetupStep.homebrewInstalled);

      // Install required tools
      final toolsToInstall = [
        (
          'sevenzip',
          SetupStep.checkingSevenZip,
          SetupStep.installingSevenZip,
        ),
        (
          'ffmpeg',
          SetupStep.checkingFfmpeg,
          SetupStep.installingFfmpeg,
        ),
        (
          'magick',
          SetupStep.checkingImageMagick,
          SetupStep.installingImageMagick,
        ),
        (
          'yt-dlp',
          SetupStep.checkingYtDlp,
          SetupStep.installingYtDlp,
        ),
        (
          'gallery-dl',
          SetupStep.checkingGalleryDl,
          SetupStep.installingGalleryDl,
        ),
        (
          'gifski',
          SetupStep.checkingGifski,
          SetupStep.installingGifski,
        ),
      ];

      for (final tool in toolsToInstall) {
        updateProgress(tool.$2);
        final result = await run(
            'which', [tool.$1 == 'sevenzip' ? '7zz' : tool.$1],
            noThrow: true);
        if (result.exitCode != 0) {
          updateProgress(tool.$3);
          final installResult =
              await run('brew', ['install', tool.$1], noThrow: true);
          if (installResult.exitCode != 0) {
            onError('Failed to install ${tool.$1}', tool.$3);
            return;
          }
        }
      }

      // Verify installations
      final verifyCommands = [
        'which 7zz',
        'which ffmpeg',
        'which magick',
        'which yt-dlp',
        'which gallery-dl',
        'which gifski',
      ];

      for (final cmd in verifyCommands) {
        final parts = cmd.split(' ');
        final result = await run(parts[0], parts.sublist(1), noThrow: true);
        if (result.exitCode != 0) {
          onError('Failed to verify ${parts[0]} installation',
              SetupStep.finishingUp);
          return;
        }
      }

      updateProgress(SetupStep.finishingUp);
      stopwatch.stop();
      logger.log(
          '[_CliSetup] Setup completed in ${stopwatch.elapsed.inSeconds}s');
      onSuccess();
    } catch (e) {
      logger.log('[_CliSetup] Error: $e');
      onError(e.toString(), setupStep.value ?? SetupStep.checkingHomebrew);
    }
  }
}

enum SetupStep {
  checkingPackageManager(label: 'Checking package manager...', progress: 0.05),
  checkingHomebrew(label: 'Checking Homebrew...', progress: 0.05),
  installingHomebrew(label: 'Installing Homebrew...', progress: 0.10),
  homebrewInstalled(label: 'Homebrew installed', progress: 0.15),
  checkingSevenZip(label: 'Checking 7-Zip...', progress: 0.20),
  installingSevenZip(label: 'Installing 7-Zip...', progress: 0.25),
  sevenZipInstalled(label: '7-Zip installed', progress: 0.30),
  checkingFfmpeg(label: 'Checking FFmpeg...', progress: 0.35),
  installingFfmpeg(label: 'Installing FFmpeg...', progress: 0.40),
  ffmpegInstalled(label: 'FFmpeg installed', progress: 0.45),
  checkingImageMagick(label: 'Checking ImageMagick...', progress: 0.50),
  installingImageMagick(label: 'Installing ImageMagick...', progress: 0.55),
  imageMagickInstalled(label: 'ImageMagick installed', progress: 0.60),
  checkingYtDlp(label: 'Checking yt-dlp...', progress: 0.65),
  installingYtDlp(label: 'Installing yt-dlp...', progress: 0.70),
  ytDlpInstalled(label: 'yt-dlp installed', progress: 0.75),
  checkingGalleryDl(label: 'Checking gallery-dl...', progress: 0.80),
  installingGalleryDl(label: 'Installing gallery-dl...', progress: 0.85),
  galleryDlInstalled(label: 'gallery-dl installed', progress: 0.90),
  checkingGifski(label: 'Checking gifski...', progress: 0.92),
  installingGifski(label: 'Installing gifski...', progress: 0.95),
  gifskiInstalled(label: 'gifski installed', progress: 0.98),
  finishingUp(label: 'Finishing up...', progress: 1.0),
  ;

  final String label;
  final double progress;

  const SetupStep({required this.label, required this.progress});
}
