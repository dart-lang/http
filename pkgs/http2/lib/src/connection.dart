// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show utf8;

import '../transport.dart';
import 'connection_preface.dart';
import 'flowcontrol/connection_queues.dart';
import 'flowcontrol/queue_messages.dart';
import 'flowcontrol/window.dart';
import 'flowcontrol/window_handler.dart';
import 'frames/frame_defragmenter.dart';
import 'frames/frames.dart';
import 'hpack/hpack.dart';
import 'ping/ping_handler.dart';
import 'settings/settings.dart';
import 'streams/stream_handler.dart';
import 'sync_errors.dart';

class ConnectionState {
  /// The connection has been established, we're waiting for the settings frame
  /// of the remote end.
  static const int Initialized = 1;

  /// The connection has been established and is fully operational.
  static const int Operational = 2;

  /// The connection is no longer accepting new streams or creating new streams.
  static const int Finishing = 3;

  /// The connection has been terminated and cannot be used anymore.
  static const int Terminated = 4;

  /// Whether we actively were finishing the connection.
  static const int FinishingActive = 1;

  /// Whether we passively were finishing the connection.
  static const int FinishingPassive = 2;

  int state = Initialized;
  int finishingState = 0;

  ConnectionState();

  bool get isInitialized => state == ConnectionState.Initialized;

  bool get isOperational => state == ConnectionState.Operational;

  bool get isFinishing => state == ConnectionState.Finishing;

  bool get isTerminated => state == ConnectionState.Terminated;

  bool get activeFinishing =>
      state == Finishing && (finishingState & FinishingActive) != 0;

  bool get passiveFinishing =>
      state == Finishing && (finishingState & FinishingPassive) != 0;

  @override
  String toString() {
    var message = '';

    void add(bool condition, String flag) {
      if (condition) {
        if (message.isEmpty) {
          message = flag;
        } else {
          message = '$message/$flag';
        }
      }
    }

    add(isInitialized, 'Initialized');
    add(isOperational, 'IsOperational');
    add(isFinishing, 'IsFinishing');
    add(isTerminated, 'IsTerminated');
    add(activeFinishing, 'ActiveFinishing');
    add(passiveFinishing, 'PassiveFinishing');

    return message;
  }
}

abstract class Connection {
  /// The settings the other end has acknowledged to use when communicating with
  /// us.
  final ActiveSettings acknowledgedSettings = ActiveSettings();

  /// The settings we have to obey communicating with the other side.
  final ActiveSettings peerSettings = ActiveSettings();

  /// Whether this connection is a client connection.
  final bool isClientConnection;

  /// Active state handler for this connection.
  ActiveStateHandler onActiveStateChanged;

  /// The HPack context for this connection.
  final HPackContext _hpackContext = HPackContext();

  /// The flow window for this connection of the peer.
  final Window _peerWindow = Window();

  /// The flow window for this connection of this end.
  final Window _localWindow = Window();

  /// Used for defragmenting PushPromise/Header frames.
  final FrameDefragmenter _defragmenter = FrameDefragmenter();

  /// The outgoing frames of this connection;
  FrameWriter _frameWriter;

  /// A subscription of incoming [Frame]s.
  StreamSubscription<Frame> _frameReaderSubscription;

  /// The incoming connection-level message queue.
  ConnectionMessageQueueIn _incomingQueue;

  /// The outgoing connection-level message queue.
  ConnectionMessageQueueOut _outgoingQueue;

  /// The ping handler used for making pings & handling remote pings.
  PingHandler _pingHandler;

  /// The settings handler used for changing settings & for handling remote
  /// setting changes.
  SettingsHandler _settingsHandler;

  /// The set of active streams this connection has.
  StreamHandler _streams;

  /// The connection-level flow control window handler for outgoing messages.
  OutgoingConnectionWindowHandler _connectionWindowHandler;

  /// The state of this connection.
  ConnectionState _state;

  Connection(Stream<List<int>> incoming, StreamSink<List<int>> outgoing,
      Settings settings,
      {this.isClientConnection = true}) {
    _setupConnection(incoming, outgoing, settings);
  }

  /// Runs all setup necessary before new streams can be created with the remote
  /// peer.
  void _setupConnection(Stream<List<int>> incoming,
      StreamSink<List<int>> outgoing, Settings settingsObject) {
    // Setup frame reading.
    var incomingFrames =
        FrameReader(incoming, acknowledgedSettings).startDecoding();
    _frameReaderSubscription = incomingFrames.listen((Frame frame) {
      _catchProtocolErrors(() => _handleFrameImpl(frame));
    }, onError: (error, stack) {
      _terminate(ErrorCode.CONNECT_ERROR, causedByTransportError: true);
    }, onDone: () {
      // Ensure existing messages from lower levels are sent to the upper
      // levels before we terminate everything.
      _incomingQueue.forceDispatchIncomingMessages();
      _streams.forceDispatchIncomingMessages();

      _terminate(ErrorCode.CONNECT_ERROR, causedByTransportError: true);
    });

    // Setup frame writing.
    _frameWriter = FrameWriter(_hpackContext.encoder, outgoing, peerSettings);
    _frameWriter.doneFuture.whenComplete(() {
      _terminate(ErrorCode.CONNECT_ERROR, causedByTransportError: true);
    });

    // Setup handlers.
    _settingsHandler = SettingsHandler(_hpackContext.encoder, _frameWriter,
        acknowledgedSettings, peerSettings);
    _pingHandler = PingHandler(_frameWriter);

    var settings = _decodeSettings(settingsObject);

    // Do the initial settings handshake (possibly with pushes disabled).
    _settingsHandler.changeSettings(settings).catchError((error) {
      // TODO: The [error] can contain sensitive information we now expose via
      // a [Goaway] frame. We should somehow ensure we're only sending useful
      // but non-sensitive information.
      _terminate(ErrorCode.PROTOCOL_ERROR,
          message: 'Failed to set initial settings (error: $error).');
    });

    _settingsHandler.onInitialWindowSizeChange.listen((int difference) {
      _catchProtocolErrors(() {
        _streams.processInitialWindowSizeSettingChange(difference);
      });
    });

    // Setup the connection window handler, which keeps track of the
    // size of the outgoing connection window.
    _connectionWindowHandler = OutgoingConnectionWindowHandler(_peerWindow);

    var connectionWindowUpdater =
        IncomingWindowHandler.connection(_frameWriter, _localWindow);

    // Setup queues for outgoing/incoming messages on the connection level.
    _outgoingQueue =
        ConnectionMessageQueueOut(_connectionWindowHandler, _frameWriter);
    _incomingQueue =
        ConnectionMessageQueueIn(connectionWindowUpdater, _catchProtocolErrors);

    if (isClientConnection) {
      _streams = StreamHandler.client(
          _frameWriter,
          _incomingQueue,
          _outgoingQueue,
          _settingsHandler.peerSettings,
          _settingsHandler.acknowledgedSettings,
          _activeStateHandler);
    } else {
      _streams = StreamHandler.server(
          _frameWriter,
          _incomingQueue,
          _outgoingQueue,
          _settingsHandler.peerSettings,
          _settingsHandler.acknowledgedSettings,
          _activeStateHandler);
    }

    // NOTE: We're not waiting until initial settings have been exchanged
    // before we start using the connection (i.e. we don't wait for half a
    // round-trip-time).
    _state = ConnectionState();
  }

  List<Setting> _decodeSettings(Settings settings) {
    var settingsList = <Setting>[];

    // By default a endpoitn can make an unlimited number of concurrent streams.
    if (settings.concurrentStreamLimit != null) {
      settingsList.add(Setting(Setting.SETTINGS_MAX_CONCURRENT_STREAMS,
          settings.concurrentStreamLimit));
    }

    // By default the stream level flow control window is 64 KiB.
    if (settings.streamWindowSize != null) {
      settingsList.add(Setting(
          Setting.SETTINGS_INITIAL_WINDOW_SIZE, settings.streamWindowSize));
    }

    if (settings is ClientSettings) {
      // By default the server is allowed to do server pushes.
      if (settings.allowServerPushes == null ||
          settings.allowServerPushes == false) {
        settingsList.add(Setting(Setting.SETTINGS_ENABLE_PUSH, 0));
      }
    } else if (settings is ServerSettings) {
      // No special server settings at the moment.
    } else {
      assert(false);
    }

    return settingsList;
  }

  /// Pings the remote peer (can e.g. be used for measuring latency).
  Future ping() {
    return _pingHandler.ping().catchError((e, s) {
      return Future.error(
          TransportException('The connection has been terminated.'));
    }, test: (e) => e is TerminatedException);
  }

  /// Finishes this connection.
  Future finish() {
    _finishing(active: true);

    // TODO: There is probably more we need to wait for.
    return _streams.done.whenComplete(() {
      var futures = [_frameWriter.close()];
      var f = _frameReaderSubscription.cancel();
      if (f != null) futures.add(f);
      return Future.wait(futures);
    });
  }

  /// Terminates this connection forcefully.
  Future terminate() {
    return _terminate(ErrorCode.NO_ERROR);
  }

  void _activeStateHandler(bool isActive) {
    if (onActiveStateChanged != null) {
      onActiveStateChanged(isActive);
    }
  }

  /// Invokes the passed in closure and catches any exceptions.
  void _catchProtocolErrors(void Function() fn) {
    try {
      fn();
    } on ProtocolException catch (error) {
      _terminate(ErrorCode.PROTOCOL_ERROR, message: '$error');
    } on FlowControlException catch (error) {
      _terminate(ErrorCode.FLOW_CONTROL_ERROR, message: '$error');
    } on FrameSizeException catch (error) {
      _terminate(ErrorCode.FRAME_SIZE_ERROR, message: '$error');
    } on HPackDecodingException catch (error) {
      _terminate(ErrorCode.PROTOCOL_ERROR, message: '$error');
    } on TerminatedException {
      // We tried to perform an action even though the connection was already
      // terminated.
      // TODO: Can this even happen and if so, how should we propagate this
      // error?
    } catch (error) {
      _terminate(ErrorCode.INTERNAL_ERROR, message: '$error');
    }
  }

  void _handleFrameImpl(Frame frame) {
    // The first frame from the other side must be a [SettingsFrame], otherwise
    // we terminate the connection.
    if (_state.isInitialized) {
      if (frame is! SettingsFrame) {
        _terminate(ErrorCode.PROTOCOL_ERROR,
            message: 'Expected to first receive a settings frame.');
        return;
      }
      _state.state = ConnectionState.Operational;
    }

    // Try to defragment [frame] if it is a Headers/PushPromise frame.
    frame = _defragmenter.tryDefragmentFrame(frame);
    if (frame == null) return;

    // Try to decode headers if it's a Headers/PushPromise frame.
    // [This needs to be done even if the frames get ignored, since the entire
    //  connection shares one HPack compression context.]
    if (frame is HeadersFrame) {
      frame.decodedHeaders =
          _hpackContext.decoder.decode(frame.headerBlockFragment);
    } else if (frame is PushPromiseFrame) {
      frame.decodedHeaders =
          _hpackContext.decoder.decode(frame.headerBlockFragment);
    }

    // Handle the frame as either a connection or a stream frame.
    if (frame.header.streamId == 0) {
      if (frame is SettingsFrame) {
        _settingsHandler.handleSettingsFrame(frame);
      } else if (frame is PingFrame) {
        _pingHandler.processPingFrame(frame);
      } else if (frame is WindowUpdateFrame) {
        _connectionWindowHandler.processWindowUpdate(frame);
      } else if (frame is GoawayFrame) {
        _streams.processGoawayFrame(frame);
        _finishing(active: false);
      } else if (frame is UnknownFrame) {
        // We can safely ignore these.
      } else {
        throw ProtocolException(
            'Cannot handle frame type ${frame.runtimeType} with stream-id 0.');
      }
    } else {
      _streams.processStreamFrame(_state, frame);
    }
  }

  void _finishing({bool active = true, String message}) {
    // If this connection is already dead, we return.
    if (_state.isTerminated) return;

    // If this connection is already finishing, we make sure to store the
    // passive bit, since this information is used by [StreamHandler].
    //
    // Vice versa should not matter: If we started passively finishing, an
    // active finish should be a NOP.
    if (_state.isFinishing) {
      if (!active) _state.finishingState |= ConnectionState.FinishingPassive;
      return;
    }

    assert(_state.isInitialized || _state.isOperational);

    // If we are actively finishing this connection, we'll send a
    // GoawayFrame otherwise we'll just propagate the message.
    if (active) {
      _state.state = ConnectionState.Finishing;
      _state.finishingState |= ConnectionState.FinishingActive;

      _outgoingQueue.enqueueMessage(GoawayMessage(
          _streams.highestPeerInitiatedStream,
          ErrorCode.NO_ERROR,
          message != null ? utf8.encode(message) : []));
    } else {
      _state.state = ConnectionState.Finishing;
      _state.finishingState |= ConnectionState.FinishingPassive;
    }

    _streams.startClosing();
  }

  /// Terminates this connection (if it is not already terminated).
  ///
  /// The returned future will never complete with an error.
  Future _terminate(int errorCode,
      {bool causedByTransportError = false, String message}) {
    // TODO: When do we complete here?
    if (_state.state != ConnectionState.Terminated) {
      _state.state = ConnectionState.Terminated;

      var cancelFuture = Future.sync(_frameReaderSubscription.cancel);
      if (!causedByTransportError) {
        _outgoingQueue.enqueueMessage(GoawayMessage(
            _streams.highestPeerInitiatedStream,
            errorCode,
            message != null ? utf8.encode(message) : []));
      }
      var closeFuture = _frameWriter.close().catchError((e, s) {
        // We ignore any errors after writing to [GoawayFrame]
      });

      // Close all lower level handlers with an error message.
      // (e.g. if there is a pending connection.ping(), it's returned
      //  Future will complete with this error).
      var exception = TransportConnectionException(
          errorCode, 'Connection is being forcefully terminated.');

      // Close all streams & stream queues
      _streams.terminate(exception);

      // Close the connection queues
      _incomingQueue.terminate(exception);
      _outgoingQueue.terminate(exception);

      _pingHandler.terminate(exception);
      _settingsHandler.terminate(exception);

      return Future.wait([cancelFuture, closeFuture]).catchError((_) {});
    }
    return Future.value();
  }
}

class ClientConnection extends Connection implements ClientTransportConnection {
  ClientConnection._(Stream<List<int>> incoming, StreamSink<List<int>> outgoing,
      Settings settings)
      : super(incoming, outgoing, settings, isClientConnection: true);

  factory ClientConnection(Stream<List<int>> incoming,
      StreamSink<List<int>> outgoing, ClientSettings clientSettings) {
    outgoing.add(CONNECTION_PREFACE);
    return ClientConnection._(incoming, outgoing, clientSettings);
  }

  @override
  bool get isOpen =>
      !_state.isFinishing && !_state.isTerminated && _streams.canOpenStream;

  @override
  ClientTransportStream makeRequest(List<Header> headers,
      {bool endStream = false}) {
    if (_state.isFinishing) {
      throw StateError(
          'The http/2 connection is finishing and can therefore not be used to '
          'make new streams.');
    } else if (_state.isTerminated) {
      throw StateError(
          'The http/2 connection is no longer active and can therefore not be '
          'used to make new streams.');
    }
    var hStream = _streams.newStream(headers, endStream: endStream);
    if (_streams.ranOutOfStreamIds) {
      _finishing(active: true, message: 'Ran out of stream ids');
    }
    return hStream;
  }
}

class ServerConnection extends Connection implements ServerTransportConnection {
  ServerConnection._(Stream<List<int>> incoming, StreamSink<List<int>> outgoing,
      Settings settings)
      : super(incoming, outgoing, settings, isClientConnection: false);

  factory ServerConnection(Stream<List<int>> incoming,
      StreamSink<List<int>> outgoing, ServerSettings serverSettings) {
    var frameBytes = readConnectionPreface(incoming);
    return ServerConnection._(frameBytes, outgoing, serverSettings);
  }

  @override
  Stream<ServerTransportStream> get incomingStreams =>
      _streams.incomingStreams.cast<ServerTransportStream>();
}
