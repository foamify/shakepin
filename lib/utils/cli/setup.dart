part of '../cli.dart';

class _CliSetup {
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
