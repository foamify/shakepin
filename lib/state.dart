import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final items = ValueNotifier<Set<String>>({});
final archiveProgress = ValueNotifier<double>(-1);
final isMinifyApp = ValueNotifier<bool>(false);
final isAboutApp = ValueNotifier<bool>(false);
const isAppStore = appFlavor != 'oss';

String formatFileSize(int size) {
  if (size < 1000) {
    return '$size B';
  } else if (size < 1000 * 1000) {
    return '${(size / 1000).toStringAsFixed(2)} KB';
  } else if (size < 1000 * 1000 * 1000) {
    return '${(size / (1000 * 1000)).toStringAsFixed(2)} MB';
  } else {
    return '${(size / (1000 * 1000 * 1000)).toStringAsFixed(2)} GB';
  }
}

extension ListenableEx<T> on ValueListenable<T> {
  T call() => value;
}

extension ListenableSetEx<T> on ValueNotifier<Set<T>> {
  void add(T item) => value = {...value, item};
  void addAll(Set<T> items) => value = {...value, ...items};
  void remove(T item) => value = {...value}..remove(item);
  void clear() => value = {};
}
