import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final items = ValueNotifier<Set<String>>({});
final archiveProgress = ValueNotifier<double>(-1);
final isMinifyApp = ValueNotifier<bool>(false);
final isAboutApp = ValueNotifier<bool>(false);
const isAppStore = appFlavor != 'oss';


extension ListenableEx<T> on ValueListenable<T> {
  T call() => value;
}

extension ListenableSetEx<T> on ValueNotifier<Set<T>> {
  void add(T item) => value = {...value, item};
  void addAll(Set<T> items) => value = {...value, ...items};
  void remove(T item) => value = {...value}..remove(item);
  void clear() => value = {};
}
