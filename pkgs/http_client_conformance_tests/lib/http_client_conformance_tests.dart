// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart';

import 'src/redirect_tests.dart';
import 'src/request_body_streamed_tests.dart';
import 'src/request_body_tests.dart';
import 'src/request_headers_tests.dart';
import 'src/response_body_streamed_test.dart';
import 'src/response_body_tests.dart';
import 'src/response_headers_tests.dart';

export 'src/redirect_tests.dart' show testRedirect;
export 'src/request_body_streamed_tests.dart' show testRequestBodyStreamed;
export 'src/request_body_tests.dart' show testRequestBody;
export 'src/request_headers_tests.dart' show testRequestHeaders;
export 'src/response_body_streamed_test.dart' show testResponseBodyStreamed;
export 'src/response_body_tests.dart' show testResponseBody;
export 'src/response_headers_tests.dart' show testResponseHeaders;

/// Runs the entire test suite against the given [Client].
///
/// If [packageRoot] is set then it will be used as the filesystem root
/// directory of `package:http_client_conformance_tests`. If it is not set then
/// `Isolate.resolvePackageUri` will be used to discover the package root.
/// NOTE: Setting this parameter is only needed in the browser environment,
/// where `Isolate.resolvePackageUri` doesn't work.
///
/// If [canStreamRequestBody] is `false` then tests that assume that the
/// [Client] supports sending HTTP requests with unbounded body sizes will be
/// skipped.
//
/// If [canStreamResponseBody] is `false` then tests that assume that the
/// [Client] supports receiving HTTP responses with unbounded body sizes will
/// be skipped
///
/// If [redirectAlwaysAllowed] is `true` then tests that require the [Client]
/// to limit redirects will be skipped.
void testAll(Client client,
    {String? packageRoot,
    bool canStreamRequestBody = true,
    bool canStreamResponseBody = true,
    bool redirectAlwaysAllowed = false}) {
  testRequestBody(client, packageRoot: packageRoot);
  testRequestBodyStreamed(client,
      packageRoot: packageRoot, canStreamRequestBody: canStreamRequestBody);
  testResponseBody(client,
      packageRoot: packageRoot, canStreamResponseBody: canStreamResponseBody);
  testResponseBodyStreamed(client,
      packageRoot: packageRoot, canStreamResponseBody: canStreamResponseBody);
  testRequestHeaders(client, packageRoot: packageRoot);
  testResponseHeaders(client, packageRoot: packageRoot);
  testRedirect(client,
      packageRoot: packageRoot, redirectAlwaysAllowed: redirectAlwaysAllowed);
}
