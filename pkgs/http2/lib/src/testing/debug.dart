// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.debug;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../transport.dart';
import '../connection_preface.dart';
import '../frames/frames.dart';
import '../settings/settings.dart';

final jsonEncoder = new JsonEncoder.withIndent('  ');

TransportConnection debugPrintingConnection(Socket socket,
    {bool isServer: true, bool verbose: true}) {
  TransportConnection connection;

  var incoming = decodeVerbose(socket, isServer, verbose: verbose);
  var outgoing = decodeOutgoingVerbose(socket, isServer, verbose: verbose);
  if (isServer) {
    connection = new ServerTransportConnection.viaStreams(incoming, outgoing);
  } else {
    connection = new ClientTransportConnection.viaStreams(incoming, outgoing);
  }
  return connection;
}

Stream<List<int>> decodeVerbose(Stream<List<int>> inc, bool isServer,
    {bool verbose: true}) {
  String name = isServer ? 'server' : 'client';

  var sc = new StreamController<List<int>>();
  var sDebug = new StreamController<List<int>>();

  _pipeAndCopy(inc, sc, sDebug);

  if (!isServer) {
    _decodeFrames(sDebug.stream).listen((frame) {
      print('[$name/stream:${frame.header.streamId}] '
          'Incoming ${frame.runtimeType}:');
      if (verbose) {
        print(jsonEncoder.convert(frame.toJson()));
        print('');
      }
    }, onError: (e, s) {
      print('[$name] Stream error: $e.');
    }, onDone: () {
      print('[$name] Closed.');
    });
  } else {
    var s3 = readConnectionPreface(sDebug.stream);
    _decodeFrames(s3).listen((frame) {
      print('[$name/stream:${frame.header.streamId}] '
          'Incoming ${frame.runtimeType}:');
      if (verbose) {
        print(jsonEncoder.convert(frame.toJson()));
        print('');
      }
    }, onError: (e, s) {
      print('[$name] Stream error: $e.');
    }, onDone: () {
      print('[$name] Closed.');
    });
  }

  return sc.stream;
}

StreamSink<List<int>> decodeOutgoingVerbose(
    StreamSink<List<int>> sink, bool isServer,
    {bool verbose: true}) {
  String name = isServer ? 'server' : 'client';

  var proxySink = new StreamController<List<int>>();
  var copy = new StreamController<List<int>>();

  if (!isServer) {
    _decodeFrames(readConnectionPreface(copy.stream)).listen((Frame frame) {
      print('[$name/stream:${frame.header.streamId}] '
          'Outgoing ${frame.runtimeType}:');
      if (verbose) {
        print(jsonEncoder.convert(frame.toJson()));
        print('');
      }
    }, onError: (e, s) {
      print('[$name] Outgoing stream error: $e');
    }, onDone: () {
      print('[$name] Closing.');
    });
  } else {
    _decodeFrames(copy.stream).listen((Frame frame) {
      print('[$name/stream:${frame.header.streamId}] '
          'Outgoing ${frame.runtimeType}:');
      if (verbose) {
        print(jsonEncoder.convert(frame.toJson()));
        print('');
      }
    }, onError: (e, s) {
      print('[$name] Outgoing stream error: $e');
    }, onDone: () {
      print('[$name] Closing.');
      proxySink.close();
    });
  }

  _pipeAndCopy(proxySink.stream, sink, copy);

  return proxySink;
}

Stream<Frame> _decodeFrames(Stream<List<int>> bytes) {
  var settings = new ActiveSettings();
  var decoder = new FrameReader(bytes, settings);
  return decoder.startDecoding();
}

Future _pipeAndCopy(Stream<List<int>> from, StreamSink to, StreamSink to2) {
  var c = new Completer();
  from.listen((List<int> data) {
    to.add(data);
    to2.add(data);
  }, onError: (e, StackTrace s) {
    to.addError(e, s);
    to2.addError(e, s);
  }, onDone: () {
    Future
        .wait([to.close(), to2.close()])
        .then(c.complete)
        .catchError(c.completeError);
  });
  return c.future;
}

void print(String s) {
  stderr.writeln(s);
}
