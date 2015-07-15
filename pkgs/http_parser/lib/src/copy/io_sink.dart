// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// The following code is copied from sdk/lib/io/io_sink.dart. The "dart:io"
// implementation isn't used directly to support non-"dart:io" applications.
//
// Because it's copied directly, only modifications necessary to support the
// desired public API and to remove "dart:io" dependencies have been made.
//
// This is up-to-date as of sdk revision
// 86227840d75d974feb238f8b3c59c038b99c05cf.
library http_parser.copy.io_sink;

import 'dart:async';

class StreamSinkImpl<T> implements StreamSink<T> {
  final StreamConsumer<T> _target;
  Completer _doneCompleter = new Completer();
  Future _doneFuture;
  StreamController<T> _controllerInstance;
  Completer _controllerCompleter;
  bool _isClosed = false;
  bool _isBound = false;
  bool _hasError = false;

  StreamSinkImpl(this._target) {
    _doneFuture = _doneCompleter.future;
  }

  void add(T data) {
    if (_isClosed) return;
    _controller.add(data);
  }

  void addError(error, [StackTrace stackTrace]) {
    _controller.addError(error, stackTrace);
  }

  Future addStream(Stream<T> stream) {
    if (_isBound) {
      throw new StateError("StreamSink is already bound to a stream");
    }
    _isBound = true;
    if (_hasError) return done;
    // Wait for any sync operations to complete.
    Future targetAddStream() {
      return _target.addStream(stream)
          .whenComplete(() {
            _isBound = false;
          });
    }
    if (_controllerInstance == null) return targetAddStream();
    var future = _controllerCompleter.future;
    _controllerInstance.close();
    return future.then((_) => targetAddStream());
  }

  Future flush() {
    if (_isBound) {
      throw new StateError("StreamSink is bound to a stream");
    }
    if (_controllerInstance == null) return new Future.value(this);
    // Adding an empty stream-controller will return a future that will complete
    // when all data is done.
    _isBound = true;
    var future = _controllerCompleter.future;
    _controllerInstance.close();
    return future.whenComplete(() {
          _isBound = false;
        });
  }

  Future close() {
    if (_isBound) {
      throw new StateError("StreamSink is bound to a stream");
    }
    if (!_isClosed) {
      _isClosed = true;
      if (_controllerInstance != null) {
        _controllerInstance.close();
      } else {
        _closeTarget();
      }
    }
    return done;
  }

  void _closeTarget() {
    _target.close().then(_completeDoneValue, onError: _completeDoneError);
  }

  Future get done => _doneFuture;

  void _completeDoneValue(value) {
    if (_doneCompleter == null) return;
    _doneCompleter.complete(value);
    _doneCompleter = null;
  }

  void _completeDoneError(error, StackTrace stackTrace) {
    if (_doneCompleter == null) return;
    _hasError = true;
    _doneCompleter.completeError(error, stackTrace);
    _doneCompleter = null;
  }

  StreamController<T> get _controller {
    if (_isBound) {
      throw new StateError("StreamSink is bound to a stream");
    }
    if (_isClosed) {
      throw new StateError("StreamSink is closed");
    }
    if (_controllerInstance == null) {
      _controllerInstance = new StreamController<T>(sync: true);
      _controllerCompleter = new Completer();
      _target.addStream(_controller.stream)
          .then(
              (_) {
                if (_isBound) {
                  // A new stream takes over - forward values to that stream.
                  _controllerCompleter.complete(this);
                  _controllerCompleter = null;
                  _controllerInstance = null;
                } else {
                  // No new stream, .close was called. Close _target.
                  _closeTarget();
                }
              },
              onError: (error, stackTrace) {
                if (_isBound) {
                  // A new stream takes over - forward errors to that stream.
                  _controllerCompleter.completeError(error, stackTrace);
                  _controllerCompleter = null;
                  _controllerInstance = null;
                } else {
                  // No new stream. No need to close target, as it have already
                  // failed.
                  _completeDoneError(error, stackTrace);
                }
              });
    }
    return _controllerInstance;
  }
}

