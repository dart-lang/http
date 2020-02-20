// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';

import '../error_matchers.dart';

void main() {
  group('settings-handler', () {
    var pushSettings = [Setting(Setting.SETTINGS_ENABLE_PUSH, 0)];
    var invalidPushSettings = [Setting(Setting.SETTINGS_ENABLE_PUSH, 2)];
    var setMaxTable256 = [Setting(Setting.SETTINGS_HEADER_TABLE_SIZE, 256)];

    test('successful-setting', () async {
      var writer = FrameWriterMock();
      var sh = SettingsHandler(
          HPackEncoder(), writer, ActiveSettings(), ActiveSettings());

      // Start changing settings.
      var changed = sh.changeSettings(pushSettings);
      verify(writer.writeSettingsFrame(pushSettings)).called(1);
      verifyNoMoreInteractions(writer);

      // Check that settings haven't been applied.
      expect(sh.acknowledgedSettings.enablePush, true);

      // Simulate remote end to respond with an ACK.
      var header =
          FrameHeader(0, FrameType.SETTINGS, SettingsFrame.FLAG_ACK, 0);
      sh.handleSettingsFrame(SettingsFrame(header, []));

      await changed;

      // Check that settings have been applied.
      expect(sh.acknowledgedSettings.enablePush, false);
    });

    test('ack-remote-settings-change', () {
      var writer = FrameWriterMock();
      var sh = SettingsHandler(
          HPackEncoder(), writer, ActiveSettings(), ActiveSettings());

      // Check that settings haven't been applied.
      expect(sh.peerSettings.enablePush, true);

      // Simulate remote end by setting the push setting.
      var header = FrameHeader(6, FrameType.SETTINGS, 0, 0);
      sh.handleSettingsFrame(SettingsFrame(header, pushSettings));

      // Check that settings have been applied.
      expect(sh.peerSettings.enablePush, false);
      verify(writer.writeSettingsAckFrame()).called(1);
      verifyNoMoreInteractions(writer);
    });

    test('invalid-remote-ack', () {
      var writer = FrameWriterMock();
      var sh = SettingsHandler(
          HPackEncoder(), writer, ActiveSettings(), ActiveSettings());

      // Simulates ACK even though we haven't sent any settings.
      var header =
          FrameHeader(0, FrameType.SETTINGS, SettingsFrame.FLAG_ACK, 0);
      var settingsFrame = SettingsFrame(header, const []);

      expect(() => sh.handleSettingsFrame(settingsFrame),
          throwsA(isProtocolException));
      verifyZeroInteractions(writer);
    });

    test('invalid-remote-settings-change', () {
      var writer = FrameWriterMock();
      var sh = SettingsHandler(
          HPackEncoder(), writer, ActiveSettings(), ActiveSettings());

      // Check that settings haven't been applied.
      expect(sh.peerSettings.enablePush, true);

      // Simulate remote end by setting the push setting.
      var header = FrameHeader(6, FrameType.SETTINGS, 0, 0);
      var settingsFrame = SettingsFrame(header, invalidPushSettings);
      expect(() => sh.handleSettingsFrame(settingsFrame),
          throwsA(isProtocolException));
      verifyZeroInteractions(writer);
    });

    test('change-max-header-table-size', () {
      var writer = FrameWriterMock();
      var mock = HPackEncoderMock();
      var sh =
          SettingsHandler(mock, writer, ActiveSettings(), ActiveSettings());

      // Simulate remote end by setting the push setting.
      var header = FrameHeader(6, FrameType.SETTINGS, 0, 0);
      var settingsFrame = SettingsFrame(header, setMaxTable256);
      sh.handleSettingsFrame(settingsFrame);
      verify(mock.updateMaxSendingHeaderTableSize(256)).called(1);
      verify(writer.writeSettingsAckFrame()).called(1);
      verifyNoMoreInteractions(mock);
      verifyNoMoreInteractions(writer);
    });
  });
}

class FrameWriterMock extends Mock implements FrameWriter {}

class HPackEncoderMock extends Mock implements HPackEncoder {}
