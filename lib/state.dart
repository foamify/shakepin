import 'package:flutter/foundation.dart';

final items = ValueNotifier<Set<String>>({});
final archiveProgress = ValueNotifier<double>(0);
final isMinifyApp = ValueNotifier<bool>(false);

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
  void add(T item) => value.add(item);
  void remove(T item) => value.remove(item);
  void clear() => value.clear();
}
