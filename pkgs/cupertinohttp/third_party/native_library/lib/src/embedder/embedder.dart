import 'embedder_standalone.dart' if (dart.library.ui) "embedder_flutter.dart"
    as embedder;

/// Whether the embedder is Flutter.
bool get isFlutter => embedder.isFlutter;

/// Whether the embedder is Dart standalone.
bool get isStandalone => embedder.isStandalone;
