// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart';

import 'src/redirect_tests.dart';
import 'src/request_body_tests.dart';
import 'src/request_headers_tests.dart';
import 'src/response_body_tests.dart';
import 'src/response_headers_tests.dart';

export 'src/redirect_tests.dart' show testRedirect;
export 'src/request_body_tests.dart' show testRequestBody;
export 'src/request_headers_tests.dart' show testRequestHeaders;
export 'src/response_body_tests.dart' show testResponseBody;
export 'src/response_headers_tests.dart' show testResponseHeaders;

/// Runs the entire test suite against the given [Client].
///
/// If [canStreamRequestBody] is `false` then tests that assume that the
/// [Client] supports sending HTTP requests with unbounded body sizes will be
/// skipped.
//
/// If [canStreamResponseBody] is `false` then tests that assume that the
/// [Client] supports receiving HTTP responses with unbounded body sizes will
/// be skipped
void testAll(Client client,
    {bool canStreamRequestBody = true, bool canStreamResponseBody = true}) {
  testRequestBody(client, canStreamRequestBody: canStreamRequestBody);
  testResponseBody(client, canStreamResponseBody: canStreamResponseBody);
  testRequestHeaders(client);
  testResponseHeaders(client);
  testRedirect(client);
}
