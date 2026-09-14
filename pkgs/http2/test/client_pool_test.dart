// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:http2/src/client_pool.dart';
import 'package:http2/src/connection.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'pool_mocks.mocks.dart';

/// Dials [MockClientConnection]s for a pool, and records what it does to them.
class _Connections {
  /// What every connection advertises as its own concurrent stream limit.
  ///
  /// Read on each call rather than captured, so a test can change a server's
  /// mind part way through.
  int? limit;

  /// When set, dialing a connection doesn't finish until this does - which is
  /// how a test controls the window where a connection exists but its own
  /// limit isn't knowable yet.
  Future<void>? dialGate;

  /// When set, closing a connection doesn't finish until this does.
  Future<void>? closeGate;

  final dialed = <ClientConnection>[];

  /// The indices of the connections that have been closed, in order.
  final closed = <int>[];

  Future<ClientConnection> dial() async {
    final index = dialed.length;
    final connection = MockClientConnection();
    dialed.add(connection);
    when(connection.peerMaxConcurrentStreams).thenAnswer((_) => limit);
    when(connection.finish()).thenAnswer((_) async {
      closed.add(index);
      if (closeGate != null) await closeGate;
      return null;
    });
    if (dialGate != null) await dialGate;
    return connection;
  }

  /// Where [connection] sits in dial order, so assertions can read as indices.
  int indexOf(ClientConnection connection) => dialed.indexOf(connection);
}

ClientPool _pool(
  _Connections connections, {
  required int maxConcurrentStreams,
  int maxIdleConnections = 1,
}) => ClientPool(
  connections.dial,
  maxConcurrentStreams: maxConcurrentStreams,
  maxIdleConnections: maxIdleConnections,
);

void main() {
  group('client-pool-test', () {
    test('dials-new-connections-as-needed', () {
      final pool = _pool(_Connections(), maxConcurrentStreams: 2);
      final completers = List.generate(3, (_) => Completer<void>());

      expect(pool.size, 0);
      unawaited(pool.run((_) => completers[0].future));
      unawaited(pool.run((_) => completers[1].future));
      expect(pool.size, 1);
      unawaited(pool.run((_) => completers[2].future));
      expect(pool.size, 2);

      for (final c in completers) {
        c.complete();
      }
    });

    test('reuses-a-connection-with-remaining-capacity', () async {
      final pool = _pool(_Connections(), maxConcurrentStreams: 2);
      final completers = List.generate(3, (_) => Completer<void>());

      final first = pool.run((_) => completers[0].future);
      unawaited(pool.run((_) => completers[1].future));
      expect(pool.size, 1);

      completers[0].complete();
      await first;

      unawaited(pool.run((_) => completers[2].future));
      expect(pool.size, 1);

      completers[1].complete();
      completers[2].complete();
    });

    test('packs-load-onto-the-most-loaded-connection', () async {
      final connections = _Connections();
      final pool = _pool(connections, maxConcurrentStreams: 2);
      final completers = List.generate(4, (_) => Completer<void>());
      final used = <int>[];

      void run(int i) => unawaited(
        pool.run((c) {
          used.add(connections.indexOf(c));
          return completers[i].future;
        }),
      );

      run(0);
      run(1);
      run(2); // Connection 0 is full - this should dial connection 1.
      await pumpEventQueue();
      expect(used, [0, 0, 1]);

      completers[0].complete();
      await pumpEventQueue();

      run(3); // Connection 0 has a free slot and is the most-loaded option.
      await pumpEventQueue();
      expect(used, [0, 0, 1, 0]);

      completers[1].complete();
      completers[2].complete();
      completers[3].complete();
    });

    test('stops-reusing-a-connection-after-a-failure', () async {
      final connections = _Connections();
      final pool = _pool(connections, maxConcurrentStreams: 10);
      final used = <int>[];

      await pool
          .run((c) {
            used.add(connections.indexOf(c));
            return Future<void>.error('boom');
          })
          .catchError((_) {});

      await pool.run((c) {
        used.add(connections.indexOf(c));
        return Future<void>.value();
      });

      expect(used, [0, 1]);
    });

    test('closes-connections-after-success', () async {
      final pool = _pool(
        _Connections(),
        maxConcurrentStreams: 2,
        maxIdleConnections: 0,
      );
      final completers = List.generate(4, (_) => Completer<void>());

      final ops = [
        pool.run((_) => completers[0].future),
        pool.run((_) => completers[1].future),
        pool.run((_) => completers[2].future),
        pool.run((_) => completers[3].future),
      ];
      expect(pool.size, 2);

      for (final c in completers) {
        c.complete();
      }
      await Future.wait(ops);

      expect(pool.size, 0);
    });

    test('closes-connections-after-an-error', () async {
      final pool = _pool(
        _Connections(),
        maxConcurrentStreams: 2,
        maxIdleConnections: 0,
      );

      final ops = List.generate(
        4,
        (_) => pool.run((_) => Future<void>.error('boom')).catchError((_) {}),
      );
      await Future.wait(ops);

      expect(pool.size, 0);
    });

    test('keeps-idle-connections-up-to-max-idle-connections', () async {
      final pool = _pool(
        _Connections(),
        maxConcurrentStreams: 1,
        maxIdleConnections: 3,
      );
      final completers = List.generate(4, (_) => Completer<void>());

      final ops = [
        pool.run((_) => completers[0].future),
        pool.run((_) => completers[1].future),
        pool.run((_) => completers[2].future),
        pool.run((_) => completers[3].future),
      ];
      expect(pool.size, 4);

      for (final c in completers) {
        c.complete();
      }
      await Future.wait(ops);

      expect(pool.size, 3);
    });

    test('honours-a-servers-own-lower-stream-limit', () async {
      final connections = _Connections()..limit = 2;
      final pool = _pool(connections, maxConcurrentStreams: 10);
      final completers = List.generate(3, (_) => Completer<void>());
      final used = <int>[];

      void run(int i) => unawaited(
        pool.run((c) {
          used.add(connections.indexOf(c));
          return completers[i].future;
        }),
      );

      run(0);
      await pool.run((_) async {}); // Let connection 0 finish dialing.
      run(1);
      run(2); // Connection 0 is at its limit of 2 - this dials another.
      await pumpEventQueue();

      expect(used, [0, 0, 1]);
      expect(pool.size, 2);

      for (final c in completers) {
        c.complete();
      }
    });

    test('ignores-a-server-limit-above-max-concurrent-streams', () async {
      final connections = _Connections()..limit = 1000;
      final pool = _pool(connections, maxConcurrentStreams: 1);
      final completers = List.generate(2, (_) => Completer<void>());

      unawaited(pool.run((_) => completers[0].future));
      await pumpEventQueue();
      unawaited(pool.run((_) => completers[1].future));
      await pumpEventQueue();

      expect(pool.size, 2);

      for (final c in completers) {
        c.complete();
      }
    });

    test('re-reads-a-server-limit-that-changes', () async {
      // Stands in for a server revising SETTINGS_MAX_CONCURRENT_STREAMS.
      final connections = _Connections()..limit = 2;
      final pool = _pool(connections, maxConcurrentStreams: 10);
      final completers = List.generate(3, (_) => Completer<void>());
      final used = <int>[];

      void run(int i) => unawaited(
        pool.run((c) {
          used.add(connections.indexOf(c));
          return completers[i].future;
        }),
      );

      run(0);
      await pool.run((_) async {}); // Let connection 0 finish dialing.
      run(1); // Still within the limit of 2, so connection 0 is reused.
      await pumpEventQueue();
      expect(used, [0, 0]);

      connections.limit = 1;
      run(2); // Connection 0 is now over its lowered limit.
      await pumpEventQueue();
      expect(used, [0, 0, 1]);

      for (final c in completers) {
        c.complete();
      }
    });

    test('keeps-a-limited-connection-that-is-merely-full', () async {
      final connections = _Connections()..limit = 1;
      final pool = _pool(connections, maxConcurrentStreams: 10);
      final completers = List.generate(2, (_) => Completer<void>());

      final first = pool.run((_) => completers[0].future);
      await pumpEventQueue();
      final second = pool.run((_) => completers[1].future);
      await pumpEventQueue();
      expect(pool.size, 2);

      completers[0].complete();
      await first;
      expect(connections.closed, isEmpty);
      expect(pool.size, 2);

      completers[1].complete();
      await second;

      expect(connections.closed, hasLength(1));
      expect(pool.size, 1);
    });

    test('rejects-work-after-terminate', () async {
      final pool = _pool(_Connections(), maxConcurrentStreams: 1);

      await pool.terminate();

      expect(() => pool.run((_) async {}), throwsA(isA<StateError>()));
    });

    test('does-not-over-commit-a-connection-whose-limit-is-unknown', () async {
      final dialGate = Completer<void>();
      final workGate = Completer<void>();
      final connections =
          _Connections()
            ..limit = 1
            ..dialGate = dialGate.future;
      final pool = _pool(
        connections,
        maxConcurrentStreams: 100,
        maxIdleConnections: 10,
      );

      final inFlight = <int, int>{};
      final peak = <int, int>{};
      final ops = List.generate(
        8,
        (_) => pool.run((c) async {
          final index = connections.indexOf(c);
          final now = (inFlight[index] ?? 0) + 1;
          inFlight[index] = now;
          peak[index] = max(peak[index] ?? 0, now);
          await workGate.future;
          inFlight[index] = inFlight[index]! - 1;
        }),
      );

      dialGate.complete();
      await pumpEventQueue();

      expect(
        peak.values,
        everyElement(1),
        reason: 'no connection may carry more streams than its limit of 1',
      );
      expect(peak, hasLength(8));

      workGate.complete();
      await Future.wait(ops);
    });

    test('tolerates-a-server-advertising-a-zero-limit', () async {
      final connections = _Connections()..limit = 0;
      final pool = _pool(connections, maxConcurrentStreams: 10);

      await expectLater(
        pool.run((c) async => connections.indexOf(c)),
        completion(0),
      );
    });

    test('a-held-lease-keeps-its-slot', () async {
      final pool = _pool(_Connections(), maxConcurrentStreams: 2);

      final lease = await pool.acquire();
      expect(pool.opCount, 1);

      lease.release();
      expect(pool.opCount, 0);
    });

    test('releasing-a-lease-twice-is-a-no-op', () async {
      final pool = _pool(_Connections(), maxConcurrentStreams: 2);

      final lease = await pool.acquire();
      lease.release();
      lease.release();

      expect(pool.opCount, 0);
    });

    test('a-failed-lease-stops-the-connection-being-reused', () async {
      final connections = _Connections();
      final pool = _pool(connections, maxConcurrentStreams: 10);
      final used = <int>[];

      final lease = await pool.acquire();
      used.add(connections.indexOf(lease.connection));
      lease.markFailed();
      lease.release();

      await pool.run((c) async => used.add(connections.indexOf(c)));

      expect(used, [0, 1]);
    });

    test('does-not-couple-a-stream-to-a-slow-close', () async {
      final connections = _Connections()..closeGate = Completer<void>().future;
      final pool = _pool(
        connections,
        maxConcurrentStreams: 1,
        maxIdleConnections: 0,
      );

      await expectLater(pool.run((_) async => 'done'), completion('done'));
    });

    test('terminate-waits-for-a-close-started-by-collection', () async {
      final gate = Completer<void>();
      final connections = _Connections()..closeGate = gate.future;
      final pool = _pool(
        connections,
        maxConcurrentStreams: 1,
        maxIdleConnections: 0,
      );

      await pool.run((_) async {});
      expect(connections.closed, [0]);

      var terminated = false;
      final termination = pool.terminate().then((_) => terminated = true);
      await pumpEventQueue();
      expect(terminated, isFalse, reason: 'the close has not finished yet');

      gate.complete();
      await termination;
      expect(terminated, isTrue);
    });

    test('terminate-is-idempotent', () async {
      final connections = _Connections();
      final pool = _pool(connections, maxConcurrentStreams: 2);
      final completer = Completer<void>();

      unawaited(pool.run((_) => completer.future));

      final first = pool.terminate();
      final second = pool.terminate();
      completer.complete();
      await Future.wait([first, second]);

      // Closed once, not once per terminate() call.
      expect(connections.closed, [0]);
      expect(pool.size, 0);
    });

    test('terminate-twice-does-not-throw-concurrent-modification', () async {
      final pool = _pool(_Connections(), maxConcurrentStreams: 1);
      final completers = List.generate(2, (_) => Completer<void>());

      final ops = [
        pool.run((_) => completers[0].future),
        pool.run((_) => completers[1].future),
      ];
      await pumpEventQueue();
      expect(pool.size, 2);

      final terminations = [pool.terminate(), pool.terminate()];
      for (final c in completers) {
        c.complete();
      }
      await Future.wait(ops);

      await expectLater(Future.wait(terminations), completes);
    });

    test('terminate-after-terminate-returns-immediately', () async {
      final connections = _Connections();
      final pool = _pool(connections, maxConcurrentStreams: 1);

      await pool.run((_) async {});
      await pool.terminate();
      await pool.terminate();

      expect(connections.closed, hasLength(lessThanOrEqualTo(1)));
    });

    test('waits-for-in-flight-streams-before-terminating', () async {
      final pool = _pool(_Connections(), maxConcurrentStreams: 1);
      final completer = Completer<void>();
      var terminated = false;

      unawaited(pool.run((_) => completer.future));
      final terminateOp = pool.terminate().then((_) => terminated = true);

      expect(terminated, isFalse);
      completer.complete();
      await terminateOp;
      expect(terminated, isTrue);
    });
  });
}
