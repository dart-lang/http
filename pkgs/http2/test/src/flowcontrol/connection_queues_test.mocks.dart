import 'dart:async' as _i5;

import 'package:http2/src/async_utils/async_utils.dart' as _i2;
import 'package:http2/src/flowcontrol/queue_messages.dart' as _i9;
import 'package:http2/src/flowcontrol/stream_queues.dart' as _i7;
import 'package:http2/src/flowcontrol/window_handler.dart' as _i3;
import 'package:http2/src/frames/frames.dart' as _i4;
import 'package:http2/src/hpack/hpack.dart' as _i6;
import 'package:http2/transport.dart' as _i8;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: comment_references

// ignore_for_file: unnecessary_parenthesis

class _FakeBufferIndicator extends _i1.Fake implements _i2.BufferIndicator {}

class _FakeIncomingWindowHandler extends _i1.Fake
    implements _i3.IncomingWindowHandler {}

/// A class which mocks [FrameWriter].
///
/// See the documentation for Mockito's code generation for more information.
class MockFrameWriter extends _i1.Mock implements _i4.FrameWriter {
  MockFrameWriter() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.BufferIndicator get bufferIndicator =>
      (super.noSuchMethod(Invocation.getter(#bufferIndicator),
          returnValue: _FakeBufferIndicator()) as _i2.BufferIndicator);

  @override
  int get highestWrittenStreamId =>
      (super.noSuchMethod(Invocation.getter(#highestWrittenStreamId),
          returnValue: 0) as int);

  @override
  _i5.Future<dynamic> get doneFuture =>
      (super.noSuchMethod(Invocation.getter(#doneFuture),
          returnValue: Future.value(null)) as _i5.Future<dynamic>);

  @override
  void writeDataFrame(int? streamId, List<int>? data,
          {bool? endStream = false}) =>
      super.noSuchMethod(Invocation.method(
          #writeDataFrame, [streamId, data], {#endStream: endStream}));

  @override
  void writeHeadersFrame(int? streamId, List<_i6.Header>? headers,
          {bool? endStream = true}) =>
      super.noSuchMethod(Invocation.method(
          #writeHeadersFrame, [streamId, headers], {#endStream: endStream}));

  @override
  void writePriorityFrame(int? streamId, int? streamDependency, int? weight,
          {bool? exclusive = false}) =>
      super.noSuchMethod(Invocation.method(#writePriorityFrame,
          [streamId, streamDependency, weight], {#exclusive: exclusive}));

  @override
  void writeRstStreamFrame(int? streamId, int? errorCode) => super.noSuchMethod(
      Invocation.method(#writeRstStreamFrame, [streamId, errorCode]));

  @override
  void writeSettingsFrame(List<_i4.Setting>? settings) =>
      super.noSuchMethod(Invocation.method(#writeSettingsFrame, [settings]));

  @override
  void writePushPromiseFrame(
          int? streamId, int? promisedStreamId, List<_i6.Header>? headers) =>
      super.noSuchMethod(Invocation.method(
          #writePushPromiseFrame, [streamId, promisedStreamId, headers]));

  @override
  void writePingFrame(int? opaqueData, {bool? ack = false}) =>
      super.noSuchMethod(
          Invocation.method(#writePingFrame, [opaqueData], {#ack: ack}));

  @override
  void writeGoawayFrame(
          int? lastStreamId, int? errorCode, List<int>? debugData) =>
      super.noSuchMethod(Invocation.method(
          #writeGoawayFrame, [lastStreamId, errorCode, debugData]));

  @override
  void writeWindowUpdate(int? sizeIncrement, {int? streamId = 0}) =>
      super.noSuchMethod(Invocation.method(
          #writeWindowUpdate, [sizeIncrement], {#streamId: streamId}));

  @override
  _i5.Future<dynamic> close() =>
      (super.noSuchMethod(Invocation.method(#close, []),
          returnValue: Future.value(null)) as _i5.Future<dynamic>);
}

/// A class which mocks [IncomingWindowHandler].
///
/// See the documentation for Mockito's code generation for more information.
class MockIncomingWindowHandler extends _i1.Mock
    implements _i3.IncomingWindowHandler {
  MockIncomingWindowHandler() {
    _i1.throwOnMissingStub(this);
  }

  @override
  int get localWindowSize =>
      (super.noSuchMethod(Invocation.getter(#localWindowSize), returnValue: 0)
          as int);

  @override
  void gotData(int? numberOfBytes) =>
      super.noSuchMethod(Invocation.method(#gotData, [numberOfBytes]));

  @override
  void dataProcessed(int? numberOfBytes) =>
      super.noSuchMethod(Invocation.method(#dataProcessed, [numberOfBytes]));
}

/// A class which mocks [StreamMessageQueueIn].
///
/// See the documentation for Mockito's code generation for more information.
class MockStreamMessageQueueIn extends _i1.Mock
    implements _i7.StreamMessageQueueIn {
  MockStreamMessageQueueIn() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.IncomingWindowHandler get windowHandler => (super.noSuchMethod(
      Invocation.getter(#windowHandler),
      returnValue: _FakeIncomingWindowHandler()) as _i3.IncomingWindowHandler);

  @override
  _i2.BufferIndicator get bufferIndicator =>
      (super.noSuchMethod(Invocation.getter(#bufferIndicator),
          returnValue: _FakeBufferIndicator()) as _i2.BufferIndicator);

  @override
  int get pendingMessages =>
      (super.noSuchMethod(Invocation.getter(#pendingMessages), returnValue: 0)
          as int);

  @override
  _i5.Stream<_i8.StreamMessage> get messages =>
      (super.noSuchMethod(Invocation.getter(#messages),
              returnValue: Stream<_i8.StreamMessage>.empty())
          as _i5.Stream<_i8.StreamMessage>);

  @override
  _i5.Stream<_i8.TransportStreamPush> get serverPushes =>
      (super.noSuchMethod(Invocation.getter(#serverPushes),
              returnValue: Stream<_i8.TransportStreamPush>.empty())
          as _i5.Stream<_i8.TransportStreamPush>);

  @override
  bool get wasTerminated =>
      (super.noSuchMethod(Invocation.getter(#wasTerminated), returnValue: false)
          as bool);

  @override
  _i5.Future<dynamic> get done => (super.noSuchMethod(Invocation.getter(#done),
      returnValue: Future.value(null)) as _i5.Future<dynamic>);

  @override
  bool get isClosing =>
      (super.noSuchMethod(Invocation.getter(#isClosing), returnValue: false)
          as bool);

  @override
  bool get wasClosed =>
      (super.noSuchMethod(Invocation.getter(#wasClosed), returnValue: false)
          as bool);

  @override
  _i5.Future<void> get onCancel =>
      (super.noSuchMethod(Invocation.getter(#onCancel),
          returnValue: Future.value(null)) as _i5.Future<void>);

  @override
  bool get wasCancelled =>
      (super.noSuchMethod(Invocation.getter(#wasCancelled), returnValue: false)
          as bool);

  @override
  void enqueueMessage(_i9.Message? message) =>
      super.noSuchMethod(Invocation.method(#enqueueMessage, [message]));

  @override
  T ensureNotTerminatedSync<T>(T Function()? f) =>
      (super.noSuchMethod(Invocation.method(#ensureNotTerminatedSync, [f]),
          returnValue: null) as T);

  @override
  _i5.Future<dynamic> ensureNotTerminatedAsync(
          _i5.Future<dynamic> Function()? f) =>
      (super.noSuchMethod(Invocation.method(#ensureNotTerminatedAsync, [f]),
          returnValue: Future.value(null)) as _i5.Future<dynamic>);

  @override
  dynamic ensureNotClosingSync(dynamic Function()? f) =>
      super.noSuchMethod(Invocation.method(#ensureNotClosingSync, [f]));
}
