// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.mock_utils;

import 'dart:mirrors';

import 'package:test/test.dart';

/// Used for mocking arbitrary classes.
///
/// Usage happens in two steps:
///   a) Make a subclass which implements a certain interface, e.g.
///      class FrameWriterMock extends SmartMock implements FrameWriter {
///        dynamic noSuchMethod(_) => super.noSuchMethod(_);
///      }
///   b) Register method mocks with e.g.
///      var writer = new FrameWriterMock();
///      writer.mock_writeSettingsFrame = (List<Setting> settings,
///                                        {bool ack: true}) {
///        // Assert settings/ack & return maybe value.
///      }
///      var settingsHandler = new SettingsHandler(hpackEncoder, writer);
///
///      // This will trigger a call on [writer] to the mocked method.
///      settingsHandler.changeSettings([]);
///
/// a) should guarantee that we do not get any checked-mode exceptions.
/// b) allows one to pass the mock into functions/other objects and mock
///    methods.
///
/// NOTE: If method signatures change, the test code must be changed and
/// the analyzer will not give any warnings if this is not done.
class SmartMock {
  final Map<String, Function> _registeredMethods = {};

  dynamic noSuchMethod(Invocation invocation) {
    var name = MirrorSystem.getName(invocation.memberName);
    var positional = invocation.positionalArguments;
    var named = invocation.namedArguments;

    handleCall() {
      var function = _registeredMethods[name];
      if (function == null) {
        throw new Exception('No mock registered for setter "$name".');
      }
      return Function.apply(function, positional, named);
    }

    handleRegistration(String name) {
      if (positional[0] == null) {
        _registeredMethods.remove(name);
      } else {
        _registeredMethods[name] = positional[0];
      }
    }

    if (invocation.isSetter) {
      if (name.startsWith('mock_')) {
        name = name.substring('mock_'.length, name.length - 1);
        return handleRegistration(name);
      } else {
        return handleCall();
      }
    } else {
      return handleCall();
    }
  }
}

/// This is a helper class for working around issues where `expectAsync`
/// cannot be used.
///
/// For example, expectAsync is not capable for wrapping functions with named
/// arguments
/// (e.g. `expectAsync((List<Setting> settings, {bool ack: true}) {})`).
class TestCounter {
  final Function _complete = expectAsync0(() {});

  final int count;
  int _got = 0;

  TestCounter({this.count: 1});

  void got() {
    _got++;
    if (_got == count) _complete();
  }
}
