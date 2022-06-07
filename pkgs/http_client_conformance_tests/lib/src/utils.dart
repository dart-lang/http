import 'dart:isolate';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

Future<StreamChannel<Object?>> startServer(String fileName) async {
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
    // The current runtime environment (probably browser) does not support
    // `Isolate.resolvePackageUri` so try to use a relative path. This will
    // *not* work if `http_client_conformance_tests` is used as a package.
    return spawnHybridUri('../lib/src/$fileName');
  }
}
