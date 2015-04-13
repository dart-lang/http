// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.error_matchers;

import 'package:unittest/unittest.dart';
import 'package:http2/src/sync_errors.dart';

const Matcher isProtocolException = const _ProtocolException();

class _ProtocolException extends TypeMatcher {
  const _ProtocolException() : super("ProtocolException");
  bool matches(item, Map matchState) => item is ProtocolException;
}

const Matcher throwsProtocolException =
    const Throws(isProtocolException);


const Matcher isFrameSizeException = const _FrameSizeException();

class _FrameSizeException extends TypeMatcher {
  const _FrameSizeException() : super("FrameSizeException");
  bool matches(item, Map matchState) => item is FrameSizeException;
}

const Matcher throwsFrameSizeException =
    const Throws(isFrameSizeException);


const Matcher isTerminatedException = const _TerminatedException();

class _TerminatedException extends TypeMatcher {
  const _TerminatedException() : super("TerminatedException");
  bool matches(item, Map matchState) => item is TerminatedException;
}

const Matcher throwsTerminatedException =
    const Throws(isTerminatedException);

