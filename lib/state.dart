import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shakepin/app/minify_app_common.dart';

final items = ValueNotifier<Set<String>>({});
final archiveProgress = ValueNotifier<double>(-1);
final isMinifyApp = ValueNotifier<bool>(false);
final isAboutApp = ValueNotifier<bool>(false);
const isAppStore = appFlavor != 'oss';

final minifiedFiles = ValueNotifier<List<MinifiedFile>>([]);
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
  void remove(T item) => value = value.where((element) => element != item).toList();
  void clear() => value = [];
}

extension ListenableSetEx<T> on ValueNotifier<Set<T>> {
  void add(T item) => value = {...value, item};
  void addAll(Iterable<T> items) => value = {...value, ...items};
  void remove(T item) => value = value.where((element) => element != item).toSet();
  void clear() => value = {};
}
