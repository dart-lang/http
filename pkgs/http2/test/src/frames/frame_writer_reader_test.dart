// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/settings/settings.dart';

import '../hpack/hpack_test.dart' show isHeader;

import '../error_matchers.dart';

main() {
  group('frames', () {
    group('writer-reader', () {
      writerReaderTest('data-frame', (FrameWriter writer,
                                      FrameReader reader,
                                      HPackDecoder decoder) async {
        writer.writeDataFrame(99, [1, 2, 3], endStream: true);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is DataFrame, isTrue);

        DataFrame dataFrame = frames[0];
        expect(dataFrame.header.streamId, 99);
        expect(dataFrame.hasPaddedFlag, isFalse);
        expect(dataFrame.padLength, 0);
        expect(dataFrame.hasEndStreamFlag, isTrue);
        expect(dataFrame.bytes, [1, 2, 3]);
      });

      writerReaderTest('headers-frame', (FrameWriter writer,
                                         FrameReader reader,
                                         HPackDecoder decoder) async {
        writer.writeHeadersFrame(
            99, [new Header.ascii('a', 'b')], endStream: true);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is HeadersFrame, isTrue);

        HeadersFrame headersFrame = frames[0];
        expect(headersFrame.header.streamId, 99);
        expect(headersFrame.hasPaddedFlag, isFalse);
        expect(headersFrame.padLength, 0);
        expect(headersFrame.hasEndStreamFlag, isTrue);
        expect(headersFrame.hasEndHeadersFlag, isTrue);
        expect(headersFrame.exclusiveDependency, false);
        expect(headersFrame.hasPriorityFlag, false);
        expect(headersFrame.streamDependency, isNull);
        expect(headersFrame.weight, isNull);

        var headers = decoder.decode(headersFrame.headerBlockFragment);
        expect(headers.length, 1);
        expect(headers[0], isHeader('a', 'b'));
      });

      writerReaderTest('priority-frame', (FrameWriter writer,
                                          FrameReader reader,
                                          HPackDecoder decoder) async {
        writer.writePriorityFrame(99, 44, 33, exclusive: true);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is PriorityFrame, isTrue);

        PriorityFrame priorityFrame = frames[0];
        expect(priorityFrame.header.streamId, 99);
        expect(priorityFrame.exclusiveDependency, isTrue);
        expect(priorityFrame.streamDependency, 44);
        expect(priorityFrame.weight, 33);
      });

      writerReaderTest('rst-frame', (FrameWriter writer,
                                     FrameReader reader,
                                     HPackDecoder decoder) async {
        writer.writeRstStreamFrame(99, 42);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is RstStreamFrame, isTrue);

        RstStreamFrame rstFrame = frames[0];
        expect(rstFrame.header.streamId, 99);
        expect(rstFrame.errorCode, 42);
      });

      writerReaderTest('settings-frame', (FrameWriter writer,
                                          FrameReader reader,
                                          HPackDecoder decoder) async {
        writer.writeSettingsFrame(
            [new Setting(Setting.SETTINGS_ENABLE_PUSH, 1)]);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is SettingsFrame, isTrue);

        SettingsFrame settingsFrame = frames[0];
        expect(settingsFrame.hasAckFlag, false);
        expect(settingsFrame.header.streamId, 0);
        expect(settingsFrame.settings.length, 1);
        expect(settingsFrame.settings[0].identifier,
               Setting.SETTINGS_ENABLE_PUSH);
        expect(settingsFrame.settings[0].value, 1);
      });

      writerReaderTest('settings-frame-ack', (FrameWriter writer,
                                              FrameReader reader,
                                              HPackDecoder decoder) async {
        writer.writeSettingsAckFrame();

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is SettingsFrame, isTrue);

        SettingsFrame settingsFrame = frames[0];
        expect(settingsFrame.hasAckFlag, true);
        expect(settingsFrame.header.streamId, 0);
        expect(settingsFrame.settings.length, 0);
      });

      writerReaderTest('push-promise-frame', (FrameWriter writer,
                                              FrameReader reader,
                                              HPackDecoder decoder) async {
        writer.writePushPromiseFrame(99, 44, [new Header.ascii('a', 'b')]);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is PushPromiseFrame, isTrue);

        PushPromiseFrame pushPromiseFrame = frames[0];
        expect(pushPromiseFrame.header.streamId, 99);
        expect(pushPromiseFrame.hasEndHeadersFlag, isTrue);
        expect(pushPromiseFrame.hasPaddedFlag, isFalse);
        expect(pushPromiseFrame.padLength, 0);
        expect(pushPromiseFrame.promisedStreamId, 44);

        var headers = decoder.decode(pushPromiseFrame.headerBlockFragment);
        expect(headers.length, 1);
        expect(headers[0], isHeader('a', 'b'));
      });

      writerReaderTest('ping-frame', (FrameWriter writer,
                                      FrameReader reader,
                                      HPackDecoder decoder) async {
        writer.writePingFrame(44, ack: true);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is PingFrame, isTrue);

        PingFrame pingFrame = frames[0];
        expect(pingFrame.header.streamId, 0);
        expect(pingFrame.opaqueData, 44);
        expect(pingFrame.hasAckFlag, isTrue);
      });

      writerReaderTest('goaway-frame', (FrameWriter writer,
                                        FrameReader reader,
                                        HPackDecoder decoder) async {
        writer.writeGoawayFrame(44, 33, [1, 2, 3]);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is GoawayFrame, isTrue);

        GoawayFrame goawayFrame = frames[0];
        expect(goawayFrame.header.streamId, 0);
        expect(goawayFrame.lastStreamId, 44);
        expect(goawayFrame.errorCode, 33);
        expect(goawayFrame.debugData, [1, 2, 3]);
      });

      writerReaderTest('window-update-frame', (FrameWriter writer,
                                               FrameReader reader,
                                               HPackDecoder decoder) async {
        writer.writeWindowUpdate(55, streamId: 99);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 1);
        expect(frames[0] is WindowUpdateFrame, isTrue);

        WindowUpdateFrame windowUpdateFrame = frames[0];
        expect(windowUpdateFrame.header.streamId, 99);
        expect(windowUpdateFrame.windowSizeIncrement, 55);
      });

      writerReaderTest('frag-headers-frame', (FrameWriter writer,
                                              FrameReader reader,
                                              HPackDecoder decoder) async {
        var headerName = [1];
        var headerValue = new List.filled(1 << 14, 0x42);
        var header = new Header(headerName, headerValue);

        writer.writeHeadersFrame(99, [header], endStream: true);

        var frames = await finishWriting(writer, reader);
        expect(frames.length, 2);
        expect(frames[0] is HeadersFrame, isTrue);
        expect(frames[1] is ContinuationFrame, isTrue);

        HeadersFrame headersFrame = frames[0];
        expect(headersFrame.header.streamId, 99);
        expect(headersFrame.hasPaddedFlag, isFalse);
        expect(headersFrame.padLength, 0);
        expect(headersFrame.hasEndHeadersFlag, isFalse);
        expect(headersFrame.hasEndStreamFlag, isTrue);
        expect(headersFrame.hasPriorityFlag, isFalse);

        ContinuationFrame contFrame = frames[1];
        expect(contFrame.header.streamId, 99);
        expect(contFrame.hasEndHeadersFlag, isTrue);

        var headerBlock = []
            ..addAll(headersFrame.headerBlockFragment)
            ..addAll(contFrame.headerBlockFragment);

        var headers = decoder.decode(headerBlock);
        expect(headers.length, 1);
        expect(headers[0].name, headerName);
        expect(headers[0].value, headerValue);
      });
    });
  });
}

writerReaderTest(String name, func(writer, reader, decoder)) {
  test(name, () {
    var settings = new ActiveSettings();
    var context = new HPackContext();
    var controller = new StreamController<List<int>>();
    var writer = new FrameWriter(context.encoder, controller, settings);
    var reader = new FrameReader(controller.stream, settings);
    return func(writer, reader, context.decoder);
  });
}

Future<List<Frame>> finishWriting(FrameWriter writer, FrameReader reader) {
  return Future.wait([writer.close(), reader.startDecoding().toList()])
      .then((results) => results.last);
}
