// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection' show UnmodifiableListView, UnmodifiableMapView;
import 'dart:developer' show Service, addHttpClientProfilingData;
import 'dart:io' show HttpClient, HttpClientResponseCompressionState;
import 'dart:isolate' show Isolate;

import 'utils.dart';

part 'http_client_request_profile.dart';
part 'http_profile_request_data.dart';
part 'http_profile_response_data.dart';
