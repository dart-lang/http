import 'dart:async';

// ignore: avoid_classes_with_only_static_members
/// An Isolate implementation for the web that throws when used.
abstract class Isolate {
  static Future<Isolate> spawn<T>(
          void Function(T message) entryPoint, T message) =>
      throw ArgumentError.value('true', 'canWorkInIsolates',
          'isolate tests are not supported on the web');
}
