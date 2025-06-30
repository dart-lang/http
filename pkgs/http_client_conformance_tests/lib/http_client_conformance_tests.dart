// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart';

import 'src/abort_tests.dart';
import 'src/close_tests.dart';
import 'src/compressed_response_body_tests.dart';
import 'src/isolate_test.dart';
import 'src/multipart_tests.dart';
import 'src/multiple_clients_tests.dart';
import 'src/redirect_tests.dart';
import 'src/request_body_streamed_tests.dart';
import 'src/request_body_tests.dart';
import 'src/request_cookies_test.dart';
import 'src/request_headers_tests.dart';
import 'src/request_methods_tests.dart';
import 'src/response_body_streamed_test.dart';
import 'src/response_body_tests.dart';
import 'src/response_cookies_test.dart';
import 'src/response_headers_tests.dart';
import 'src/response_status_line_tests.dart';
import 'src/server_errors_test.dart';

export 'src/abort_tests.dart' show testAbort;
export 'src/close_tests.dart' show testClose;
export 'src/compressed_response_body_tests.dart'
    show testCompressedResponseBody;
export 'src/isolate_test.dart' show testIsolate;
export 'src/multipart_tests.dart' show testMultipartRequests;
export 'src/multiple_clients_tests.dart' show testMultipleClients;
export 'src/redirect_tests.dart' show testRedirect;
export 'src/request_body_streamed_tests.dart' show testRequestBodyStreamed;
export 'src/request_body_tests.dart' show testRequestBody;
export 'src/request_cookies_test.dart' show testRequestCookies;
export 'src/request_headers_tests.dart' show testRequestHeaders;
export 'src/request_methods_tests.dart' show testRequestMethods;
export 'src/response_body_streamed_test.dart' show testResponseBodyStreamed;
export 'src/response_body_tests.dart' show testResponseBody;
export 'src/response_cookies_test.dart' show testResponseCookies;
export 'src/response_headers_tests.dart' show testResponseHeaders;
export 'src/response_status_line_tests.dart' show testResponseStatusLine;
export 'src/server_errors_test.dart' show testServerErrors;

/// Runs the entire test suite against the given [Client].
///
/// If [canStreamRequestBody] is `false` then tests that assume that the
/// [Client] supports sending HTTP requests with unbounded body sizes will be
/// skipped.
//
/// If [canStreamResponseBody] is `false` then tests that assume that the
/// [Client] supports receiving HTTP responses with unbounded body sizes will
/// be skipped.
///
/// If [redirectAlwaysAllowed] is `true` then tests that require the [Client]
/// to limit redirects will be skipped.
///
/// If [canWorkInIsolates] is `false` then tests that require that the [Client]
/// work in Isolates other than the main isolate will be skipped.
///
/// If [preservesMethodCase] is `false` then tests that assume that the
/// [Client] preserves custom request method casing will be skipped.
///
/// If [canSendCookieHeaders] is `false` then tests that require that "cookie"
/// headers be sent by the client will not be run.
///
/// If [canReceiveSetCookieHeaders] is `false` then tests that require that
/// "set-cookie" headers be received by the client will not be run.
///
/// If [supportsFoldedHeaders] is `false` then the tests that assume that the
/// [Client] can parse folded headers will be skipped.
///
/// If [correctlyHandlesNullHeaderValues] is `false` then the tests that assume
/// that the [Client] correctly deals with NUL in header values are skipped.
///
/// If [supportsMultipartRequest] is `false` then tests that assume that
/// multipart requests can be sent will be skipped.
///
/// If [supportsAbort] is `false` then tests that assume that requests can be
/// aborted will be skipped.
///
/// The tests are run against a series of HTTP servers that are started by the
/// tests. If the tests are run in the browser, then the test servers are
/// started in another process. Otherwise, the test servers are run in-process.
void testAll(
  Client Function() clientFactory, {
  bool canStreamRequestBody = true,
  bool canStreamResponseBody = true,
  bool redirectAlwaysAllowed = false,
  bool canWorkInIsolates = true,
  bool preservesMethodCase = false,
  bool supportsFoldedHeaders = true,
  bool correctlyHandlesNullHeaderValues = true,
  bool canSendCookieHeaders = false,
  bool canReceiveSetCookieHeaders = false,
  bool supportsMultipartRequest = true,
  bool supportsAbort = false,
}) {
  testRequestBody(clientFactory());
  testRequestBodyStreamed(clientFactory(),
      canStreamRequestBody: canStreamRequestBody);
  testResponseBody(clientFactory(),
      canStreamResponseBody: canStreamResponseBody);
  testResponseBodyStreamed(clientFactory(),
      canStreamResponseBody: canStreamResponseBody);
  testRequestHeaders(clientFactory());
  testRequestMethods(clientFactory(), preservesMethodCase: preservesMethodCase);
  testResponseHeaders(clientFactory(),
      supportsFoldedHeaders: supportsFoldedHeaders,
      correctlyHandlesNullHeaderValues: correctlyHandlesNullHeaderValues);
  testResponseStatusLine(clientFactory());
  testRedirect(clientFactory(), redirectAlwaysAllowed: redirectAlwaysAllowed);
  testServerErrors(clientFactory());
  testCompressedResponseBody(clientFactory());
  testMultipleClients(clientFactory);
  testMultipartRequests(clientFactory(),
      supportsMultipartRequest: supportsMultipartRequest);
  testClose(clientFactory);
  testIsolate(clientFactory, canWorkInIsolates: canWorkInIsolates);
  testRequestCookies(clientFactory(),
      canSendCookieHeaders: canSendCookieHeaders);
  testResponseCookies(clientFactory(),
      canReceiveSetCookieHeaders: canReceiveSetCookieHeaders);
  testAbort(clientFactory(),
      supportsAbort: supportsAbort,
      canStreamRequestBody: canStreamRequestBody,
      canStreamResponseBody: canStreamResponseBody);
}
