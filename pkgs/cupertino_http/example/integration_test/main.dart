// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:integration_test/integration_test.dart';

import 'client_conformance_test.dart' as client_conformance_test;
import 'client_profile_test.dart' as profile_test;
import 'client_test.dart' as client_test;
import 'data_test.dart' as data_test;
import 'error_test.dart' as error_test;
import 'http_url_response_test.dart' as http_url_response_test;
import 'mutable_data_test.dart' as mutable_data_test;
import 'mutable_url_request_test.dart' as mutable_url_request_test;
import 'url_cache_test.dart' as url_cache_test;
import 'url_request_test.dart' as url_request_test;
import 'url_response_test.dart' as url_response_test;
import 'url_session_configuration_test.dart' as url_session_configuration_test;
import 'url_session_delegate_test.dart' as url_session_delegate_test;
import 'url_session_task_test.dart' as url_session_task_test;
import 'url_session_test.dart' as url_session_test;
import 'utils_test.dart' as utils_test;
import 'web_socket_conformance_test.dart' as web_socket_conformance_test;

/// Execute all the tests in this directory.
///
/// This is faster than running each test individually using
/// `flutter test integration_test/` because only one compilation step and
/// application launch is required.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  client_conformance_test.main();
  profile_test.main();
  client_test.main();
  data_test.main();
  error_test.main();
  http_url_response_test.main();
  mutable_data_test.main();
  mutable_url_request_test.main();
  url_cache_test.main();
  url_request_test.main();
  url_response_test.main();
  url_session_configuration_test.main();
  url_session_delegate_test.main();
  url_session_task_test.main();
  url_session_test.main();
  utils_test.main();
  web_socket_conformance_test.main();
}
