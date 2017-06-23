// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html' as html;

import 'package:http/http.dart';
import 'package:http/browser_client.dart';

Client platformClient() => new BrowserClient();

String userAgent() => html.window.navigator.userAgent;
