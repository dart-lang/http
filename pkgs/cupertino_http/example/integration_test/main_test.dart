// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:integration_test/integration_test.dart';

import 'client_conformance.dart' as client_conformance;
import 'data.dart' as data;
import 'error.dart' as error;
import 'http_url_response.dart' as http_url_response;
import 'mutable_data.dart' as mutable_data;
import 'mutable_url_request.dart' as mutable_url_request;
import 'url_request.dart' as url_request;
import 'url_response.dart' as url_response;
import 'url_session.dart' as url_session;
import 'url_session_configuration.dart' as url_session_configuration;
import 'url_session_delegate.dart' as url_session_delegate;
import 'url_session_task.dart' as url_session_task;
import 'utils.dart' as utils;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  client_conformance.main();
  data.main();
  error.main();
  http_url_response.main();
  mutable_data.main();
  mutable_url_request.main();
  url_request.main();
  url_response.main();
  url_session_configuration.main();
  url_session_delegate.main();
  url_session_task.main();
  url_session.main();
  utils.main();
}
