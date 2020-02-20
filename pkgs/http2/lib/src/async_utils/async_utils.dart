// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

/// An interface for `StreamSink`-like classes to indicate whether adding data
/// would be buffered and when the buffer is empty again.
class BufferIndicator {
  final StreamController _controller = StreamController.broadcast(sync: true);

  /// A state variable indicating whether buffereing would occur at the moment.
  bool _wouldBuffer = true;

  /// Indicates whether calling [BufferedBytesWriter.add] would buffer the data
  /// if called.
  ///
  /// This can be used at a higher level as a way to do custom buffering and
  /// possibly prioritization.
  bool get wouldBuffer {
    return _wouldBuffer;
  }

  /// Signals that no buffering is happening at the moment.
  void markUnBuffered() {
    if (_wouldBuffer) {
      _wouldBuffer = false;
      _controller.add(null);
    }
  }

  /// Signals that buffering starts to happen.
  void markBuffered() {
    _wouldBuffer = true;
  }

  /// A broadcast stream notifying users that the [BufferedBytesWriter.add]
  /// method would not buffer the data if called.
  Stream get bufferEmptyEvents => _controller.stream;
}

/// Contains a [StreamSink] and a [BufferIndicator] to indicate whether writes
/// to the sink would cause buffering.
///
/// It uses the `pause signal` from the `sink.addStream()` as an indicator
/// whether the underlying stream cannot handle more data and would buffer.
class BufferedSink {
  /// The indicator whether the underlying sink is buffering at the moment.
  final BufferIndicator bufferIndicator = BufferIndicator();

  /// A intermediate [StreamController] used to catch pause signals and to
  /// propagate the change via [bufferIndicator].
  StreamController<List<int>> _controller;

  /// A future which completes once the sink has been closed.
  Future _doneFuture;

  BufferedSink(StreamSink<List<int>> dataSink) {
    bufferIndicator.markBuffered();

    _controller = StreamController<List<int>>(
        onListen: () {
          bufferIndicator.markUnBuffered();
        },
        onPause: () {
          bufferIndicator.markBuffered();
        },
        onResume: () {
          bufferIndicator.markUnBuffered();
        },
        onCancel: () {
          // TODO: We may want to propagate cancel events as errors.
          // Currently `_doneFuture` will just complete normally if the sink
          // cancelled.
        },
        sync: true);
    _doneFuture =
        Future.wait([_controller.stream.pipe(dataSink), dataSink.done]);
  }

  /// The underlying sink.
  StreamSink<List<int>> get sink => _controller;

  /// The future which will complete once this sink has been closed.
  Future get doneFuture => _doneFuture;
}

/// A small wrapper around [BufferedSink] which writes data in batches.
class BufferedBytesWriter {
  /// A buffer which will be used for batching writes.
  final BytesBuilder _builder = BytesBuilder(copy: false);

  /// The underlying [BufferedSink].
  final BufferedSink _bufferedSink;

  BufferedBytesWriter(StreamSink<List<int>> outgoing)
      : _bufferedSink = BufferedSink(outgoing);

  /// An indicator whether the underlying sink is buffering at the moment.
  BufferIndicator get bufferIndicator => _bufferedSink.bufferIndicator;

  /// Adds [data] immediately to the underlying buffer.
  ///
  /// If there is buffered data which was added with [addBufferedData] and it
  /// has not been flushed with [flushBufferedData] an error will be thrown.
  void add(List<int> data) {
    if (_builder.length > 0) {
      throw StateError(
          'Cannot trigger an asynchronous write while there is buffered data.');
    }
    _bufferedSink.sink.add(data);
  }

  /// Queues up [bytes] to be written.
  void addBufferedData(List<int> bytes) {
    _builder.add(bytes);
  }

  /// Flushes all data which was enqueued by [addBufferedData].
  void flushBufferedData() {
    if (_builder.length > 0) {
      _bufferedSink.sink.add(_builder.takeBytes());
    }
  }

  /// Closes this sink.
  Future close() {
    flushBufferedData();
    return _bufferedSink.sink.close().whenComplete(() => doneFuture);
  }

  /// The future which will complete once this sink has been closed.
  Future get doneFuture => _bufferedSink.doneFuture;
}
