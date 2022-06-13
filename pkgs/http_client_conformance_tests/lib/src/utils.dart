import 'dart:isolate';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Starts a test server using a relative path name e.g.
/// 'redirect_server.dart'. If [packageRoot] is set then [fileName] will be
/// interpreted as relative to it.
///
/// See [spawnHybridUri].
Future<StreamChannel<Object?>> startServer(
    String fileName, String? packageRoot) async {
  if (packageRoot != null) {
    return spawnHybridUri('$packageRoot/lib/src/$fileName');
  }
  try {
    final fileUri = await Isolate.resolvePackageUri(Uri(
        scheme: 'package',
        path: 'http_client_conformance_tests/src/$fileName'));
    if (fileUri == null) {
      throw StateError('The package could not be resolved');
    }
    return spawnHybridUri(fileUri);
    // ignore: avoid_catching_errors
  } on UnsupportedError {
    throw StateError(
        'The path for package:http_client_conformance_tests could not be '
        'found in the current environment');
  }
}
