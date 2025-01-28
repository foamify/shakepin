import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

final items = ValueNotifier<Set<String>>({});
final selectedItems = ValueNotifier<Set<String>>({});
final archiveProgress = ValueNotifier<double>(-1);
final isMinifyApp = ValueNotifier<bool>(false);
final isAboutApp = ValueNotifier<bool>(false);
final isLicenseApp = ValueNotifier<bool>(false);

const isAppStore = appFlavor != 'oss';

final outputDirectory = ValueNotifier<String?>(null);

// Function to update the output directory
void updateOutputDirectory(String? newDirectory) {
  outputDirectory.value = newDirectory;
}

// Function to load or select a new output directory
Future<void> loadOutputDirectory() async {
  if (outputDirectory.value == null) {
    final String? selectedDirectory = await getDirectoryPath();
    if (selectedDirectory != null) {
      updateOutputDirectory(selectedDirectory);
    }
  }
}

extension ListenableEx<T> on ValueListenable<T> {
  T call() => value;
}

extension ListenableListEx<T> on ValueNotifier<List<T>> {
  void add(T item) => value = [...value, item];
  void addAll(Iterable<T> items) => value = [...value, ...items];
  void remove(T item) =>
      value = value.where((element) => element != item).toList();
  void clear() => value = [];
}

extension ListenableSetEx<T> on ValueNotifier<Set<T>> {
  void add(T item) => value = {...value, item};
  void addAll(Iterable<T> items) => value = {...value, ...items};
  void remove(T item) =>
      value = value.where((element) => element != item).toSet();
  void clear() => value = {};
}

final isMiscApp = ValueNotifier<bool>(false);

// Update the existing variables or add if not present:
late final SharedPreferences prefs;

final appMode = ValueNotifier<AppMode>(AppMode.pin);

enum AppMode {
  pin._(),
  minify._(),
  archive._(),
  // Start of misc apps
  convertToWav._('Extract Audio'),
  convertToIco._('Convert to ICO'),
  downloadVideo._('Download Video'),
  downloadMedia._('Download Media'),
  ;

  /// The label of misc apps. Returns null for non-misc apps.
  final String? label;

  const AppMode._([this.label]);
}

extension AppModeEx on AppMode {
  bool isFileCompatible(String path) => switch (this) {
        AppMode.minify =>
          (isImageFile(path) || isVideoFile(path)) && !isUrl(path),
        AppMode.archive => !isUrl(path),
        AppMode.convertToIco => isImageFile(path),
        AppMode.convertToWav => isVideoFile(path) || isAudioFile(path),
        AppMode.downloadVideo || AppMode.downloadMedia => isUrl(path),
        AppMode.pin => true,
      };
}

void handleModeChanged(AppMode mode) async {
  final appSize = switch (mode) {
    AppMode.pin => AppSizes.pin,
    AppMode.minify => AppSizes.minify,
    AppMode.archive => AppSizes.archive,
    _ => AppSizes.misc,
  };

  appMode.value = mode;

  dropChannel.setMinimumSize(appSize);
  final rect = Rect.fromCenter(
    center: await dropChannel.center(),
    width: appSize.width,
    height: appSize.height,
  );
  dropChannel.setFrame(rect, animate: true);
}

final setupProgress = ValueNotifier<double>(0);
final setupStep = ValueNotifier<String>('');
final setupSuccess = ValueNotifier<bool?>(null);
