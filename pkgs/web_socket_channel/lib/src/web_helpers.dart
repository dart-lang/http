// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web/helpers.dart';

// TODO(kevmoo): remove when https://github.com/dart-lang/web/commit/4cb5811ed06
// is in a published release and the min constraint on pkg:web is updated
extension WebSocketEvents on WebSocket {
  Stream<Event> get onOpenX => EventStreamProviders.openEvent.forTarget(this);
  Stream<MessageEvent> get onMessageX =>
      EventStreamProviders.messageEvent.forTarget(this);
  Stream<CloseEvent> get onCloseX =>
      EventStreamProviders.closeEvent.forTarget(this);
  Stream<Event> get onErrorX =>
      EventStreamProviders.errorEventSourceEvent.forTarget(this);
}
