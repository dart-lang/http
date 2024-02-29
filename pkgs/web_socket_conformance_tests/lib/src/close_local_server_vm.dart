// Generated by generate_server_wrappers.dart. Do not edit.

import 'package:stream_channel/stream_channel.dart';

import 'close_local_server.dart';

/// Starts the redirect test HTTP server in the same process.
Future<StreamChannel<Object?>> startServer() async {
  final controller = StreamChannelController<Object?>(sync: true);
  hybridMain(controller.foreign);
  return controller.local;
}
