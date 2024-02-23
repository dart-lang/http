// Generated by generate_server_wrappers.dart. Do not edit.

import 'package:stream_channel/stream_channel.dart';

import 'multiple_clients_server.dart';

export 'server_queue_helpers.dart' show StreamQueueOfNullableObjectExtension;

/// Starts the redirect test HTTP server in the same process.
Future<StreamChannel<Object?>> startServer() async {
  final controller = StreamChannelController<Object?>(sync: true);
  hybridMain(controller.foreign);
  return controller.local;
}
