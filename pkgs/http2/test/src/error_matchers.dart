// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.error_matchers;

import 'package:test/test.dart';
import 'package:http2/src/sync_errors.dart';

const Matcher isProtocolException = const TypeMatcher<ProtocolException>();
const Matcher isFrameSizeException = const TypeMatcher<FrameSizeException>();
const Matcher isTerminatedException = const TypeMatcher<TerminatedException>();
const Matcher isFlowControlException =
    const TypeMatcher<FlowControlException>();
