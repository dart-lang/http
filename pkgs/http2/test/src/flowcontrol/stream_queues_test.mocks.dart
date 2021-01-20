import 'dart:async' as _i4;

import 'package:http2/src/async_utils/async_utils.dart' as _i2;
import 'package:http2/src/flowcontrol/connection_queues.dart' as _i3;
import 'package:http2/src/flowcontrol/queue_messages.dart' as _i5;
import 'package:http2/src/flowcontrol/window_handler.dart' as _i6;
import 'package:http2/src/frames/frames.dart' as _i7;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: comment_references

// ignore_for_file: unnecessary_parenthesis

class _FakeBufferIndicator extends _i1.Fake implements _i2.BufferIndicator {}

/// A class which mocks [ConnectionMessageQueueOut].
///
/// See the documentation for Mockito's code generation for more information.
class MockConnectionMessageQueueOut extends _i1.Mock
    implements _i3.ConnectionMessageQueueOut {
  MockConnectionMessageQueueOut() {
    _i1.throwOnMissingStub(this);
  }

  @override
  int get pendingMessages =>
      (super.noSuchMethod(Invocation.getter(#pendingMessages), 0) as int);
  @override
  bool get wasTerminated =>
      (super.noSuchMethod(Invocation.getter(#wasTerminated), false) as bool);
  @override
  _i4.Future<dynamic> get done =>
      (super.noSuchMethod(Invocation.getter(#done), Future.value(null))
          as _i4.Future<dynamic>);
  @override
  bool get isClosing =>
      (super.noSuchMethod(Invocation.getter(#isClosing), false) as bool);
  @override
  bool get wasClosed =>
      (super.noSuchMethod(Invocation.getter(#wasClosed), false) as bool);
  @override
  void enqueueMessage(_i5.Message? message) =>
      super.noSuchMethod(Invocation.method(#enqueueMessage, [message]));
  @override
  T ensureNotTerminatedSync<T>(T Function()? f) => (super.noSuchMethod(
      Invocation.method(#ensureNotTerminatedSync, [f]), null) as T);
  @override
  _i4.Future<dynamic> ensureNotTerminatedAsync(
          _i4.Future<dynamic> Function()? f) =>
      (super.noSuchMethod(Invocation.method(#ensureNotTerminatedAsync, [f]),
          Future.value(null)) as _i4.Future<dynamic>);
  @override
  dynamic ensureNotClosingSync(dynamic Function()? f) =>
      super.noSuchMethod(Invocation.method(#ensureNotClosingSync, [f]));
}

/// A class which mocks [IncomingWindowHandler].
///
/// See the documentation for Mockito's code generation for more information.
class MockIncomingWindowHandler extends _i1.Mock
    implements _i6.IncomingWindowHandler {
  MockIncomingWindowHandler() {
    _i1.throwOnMissingStub(this);
  }

  @override
  int get localWindowSize =>
      (super.noSuchMethod(Invocation.getter(#localWindowSize), 0) as int);
  @override
  void gotData(int? numberOfBytes) =>
      super.noSuchMethod(Invocation.method(#gotData, [numberOfBytes]));
  @override
  void dataProcessed(int? numberOfBytes) =>
      super.noSuchMethod(Invocation.method(#dataProcessed, [numberOfBytes]));
}

/// A class which mocks [OutgoingStreamWindowHandler].
///
/// See the documentation for Mockito's code generation for more information.
class MockOutgoingStreamWindowHandler extends _i1.Mock
    implements _i6.OutgoingStreamWindowHandler {
  MockOutgoingStreamWindowHandler() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.BufferIndicator get positiveWindow => (super.noSuchMethod(
          Invocation.getter(#positiveWindow), _FakeBufferIndicator())
      as _i2.BufferIndicator);
  @override
  int get peerWindowSize =>
      (super.noSuchMethod(Invocation.getter(#peerWindowSize), 0) as int);
  @override
  void processInitialWindowSizeSettingChange(int? difference) =>
      super.noSuchMethod(Invocation.method(
          #processInitialWindowSizeSettingChange, [difference]));
  @override
  void processWindowUpdate(_i7.WindowUpdateFrame? frame) =>
      super.noSuchMethod(Invocation.method(#processWindowUpdate, [frame]));
  @override
  void decreaseWindow(int? numberOfBytes) =>
      super.noSuchMethod(Invocation.method(#decreaseWindow, [numberOfBytes]));
}
