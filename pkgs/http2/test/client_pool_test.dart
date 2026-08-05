// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:http2/src/client_pool.dart';
import 'package:test/test.dart';

ClientPool<int> _pool({
  required int maxConcurrentOperations,
  int maxIdleResources = 1,
  int? Function(int resource)? concurrencyLimitOf,
  List<int>? destroyed,
  Future<void>? destroyGate,
  Future<void>? dialGate,
}) {
  var nextId = 0;
  return ClientPool<int>(
    () async {
      final id = nextId++;
      if (dialGate != null) await dialGate;
      return id;
    },
    maxConcurrentOperations: maxConcurrentOperations,
    maxIdleResources: maxIdleResources,
    destroy: (resource) async {
      destroyed?.add(resource);
      if (destroyGate != null) await destroyGate;
    },
    concurrencyLimitOf: concurrencyLimitOf,
  );
}

void main() {
  group('client-pool-test', () {
    test('creates-new-resources-as-needed', () {
      final pool = _pool(maxConcurrentOperations: 2);
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

    test('reuses-resource-with-remaining-capacity', () async {
      final pool = _pool(maxConcurrentOperations: 2);
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

    test('packs-load-onto-most-full-resource', () async {
      final pool = _pool(maxConcurrentOperations: 2);
      final completers = List.generate(4, (_) => Completer<void>());
      final resourcesUsed = <int>[];

      void run(int i) => unawaited(
        pool.run((r) {
          resourcesUsed.add(r);
          return completers[i].future;
        }),
      );

      run(0);
      run(1);
      run(2); // Resource 0 is full - this should open resource 1.
      await Future<void>.value();
      expect(resourcesUsed, [0, 0, 1]);

      completers[0].complete();
      await Future<void>.value();

      run(3); // Resource 0 has a free slot again and is the most-full option.
      await Future<void>.value();
      expect(resourcesUsed, [0, 0, 1, 0]);

      completers[1].complete();
      completers[2].complete();
      completers[3].complete();
    });

    test('stops-reusing-resource-after-failure', () async {
      final pool = _pool(maxConcurrentOperations: 10);
      final resourcesUsed = <int>[];

      await pool
          .run((r) {
            resourcesUsed.add(r);
            return Future<void>.error('boom');
          })
          .catchError((_) {});

      await pool.run((r) {
        resourcesUsed.add(r);
        return Future<void>.value();
      });

      expect(resourcesUsed, [0, 1]);
    });

    test('garbage-collects-after-success', () async {
      final pool = _pool(maxConcurrentOperations: 2, maxIdleResources: 0);
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

    test('garbage-collects-after-error', () async {
      final pool = _pool(maxConcurrentOperations: 2, maxIdleResources: 0);

      final ops = List.generate(
        4,
        (_) => pool.run((_) => Future<void>.error('boom')).catchError((_) {}),
      );
      await Future.wait(ops);

      expect(pool.size, 0);
    });

    test('keeps-idle-resources-up-to-max-idle-resources', () async {
      final pool = _pool(maxConcurrentOperations: 1, maxIdleResources: 3);
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

    test('honours-a-resources-own-lower-concurrency-limit', () async {
      final pool = _pool(
        maxConcurrentOperations: 10,
        concurrencyLimitOf: (_) => 2,
      );
      final completers = List.generate(3, (_) => Completer<void>());
      final resourcesUsed = <int>[];

      void run(int i) => unawaited(
        pool.run((r) {
          resourcesUsed.add(r);
          return completers[i].future;
        }),
      );

      run(0);
      await pool.run((_) async {});
      run(1);
      run(2); // Resource 0 is at its own limit of 2 - this opens resource 1.
      await Future<void>.value();

      expect(resourcesUsed, [0, 0, 1]);
      expect(pool.size, 2);

      for (final c in completers) {
        c.complete();
      }
    });

    test('ignores-a-resource-limit-above-max-concurrent-operations', () async {
      final pool = _pool(
        maxConcurrentOperations: 1,
        concurrencyLimitOf: (_) => 1000,
      );
      final completers = List.generate(2, (_) => Completer<void>());

      unawaited(pool.run((_) => completers[0].future));
      await Future<void>.value();
      unawaited(pool.run((_) => completers[1].future));
      await Future<void>.value();

      expect(pool.size, 2);

      for (final c in completers) {
        c.complete();
      }
    });

    test('re-reads-a-resource-limit-that-changes', () async {
      var limit = 2;
      final pool = _pool(
        maxConcurrentOperations: 10,
        concurrencyLimitOf: (_) => limit,
      );
      final completers = List.generate(3, (_) => Completer<void>());
      final resourcesUsed = <int>[];

      void run(int i) => unawaited(
        pool.run((r) {
          resourcesUsed.add(r);
          return completers[i].future;
        }),
      );

      run(0);
      await pool.run((_) async {}); // Let resource 0 resolve.
      run(1); // Still within the limit of 2, so resource 0 is reused.
      await Future<void>.value();
      expect(resourcesUsed, [0, 0]);

      limit = 1;
      run(2); // Resource 0 is now over its lowered limit, so a new one opens.
      await Future<void>.value();
      expect(resourcesUsed, [0, 0, 1]);

      for (final c in completers) {
        c.complete();
      }
    });

    test('keeps-a-limited-resource-that-is-merely-full', () async {
      final destroyed = <int>[];
      final pool = _pool(
        maxConcurrentOperations: 10,
        concurrencyLimitOf: (_) => 1,
        destroyed: destroyed,
      );
      final completers = List.generate(2, (_) => Completer<void>());

      final first = pool.run((_) => completers[0].future);
      await Future<void>.value();
      final second = pool.run((_) => completers[1].future);
      await Future<void>.value();
      expect(pool.size, 2);

      completers[0].complete();
      await first;
      expect(destroyed, isEmpty);
      expect(pool.size, 2);

      completers[1].complete();
      await second;

      expect(destroyed, hasLength(1));
      expect(pool.size, 1);
    });

    test('rejects-operations-after-terminate', () async {
      final pool = _pool(maxConcurrentOperations: 1);

      await pool.terminate();

      expect(() => pool.run((_) async {}), throwsA(isA<StateError>()));
    });

    test(
      'does-not-over-commit-a-resource-whose-limit-is-not-known-yet',
      () async {
        final dialGate = Completer<void>();
        final workGate = Completer<void>();
        final pool = _pool(
          maxConcurrentOperations: 100,
          maxIdleResources: 10,
          concurrencyLimitOf: (_) => 1,
          dialGate: dialGate.future,
        );

        final inFlight = <int, int>{};
        final peak = <int, int>{};
        final ops = List.generate(
          8,
          (_) => pool.run((r) async {
            final now = (inFlight[r] ?? 0) + 1;
            inFlight[r] = now;
            peak[r] = max(peak[r] ?? 0, now);
            await workGate.future;
            inFlight[r] = inFlight[r]! - 1;
          }),
        );

        dialGate.complete();
        await pumpEventQueue();

        expect(
          peak.values,
          everyElement(1),
          reason: 'no resource may run more than its own limit of 1',
        );
        expect(peak, hasLength(8));

        workGate.complete();
        await Future.wait(ops);
      },
    );

    test('tolerates-a-resource-that-reports-a-zero-limit', () async {
      final pool = _pool(
        maxConcurrentOperations: 10,
        concurrencyLimitOf: (_) => 0,
      );

      await expectLater(pool.run((r) async => r), completion(0));
    });

    test('a-held-lease-keeps-its-slot', () async {
      final pool = _pool(maxConcurrentOperations: 2);

      final lease = await pool.acquire();
      expect(pool.opCount, 1);

      lease.release();
      expect(pool.opCount, 0);
    });

    test('releasing-a-lease-twice-is-a-no-op', () async {
      final pool = _pool(maxConcurrentOperations: 2);

      final lease = await pool.acquire();
      lease.release();
      lease.release();

      expect(pool.opCount, 0);
    });

    test('a-failed-lease-stops-the-resource-being-reused', () async {
      final pool = _pool(maxConcurrentOperations: 10);
      final resourcesUsed = <int>[];

      final lease = await pool.acquire();
      resourcesUsed.add(lease.value);
      lease.markFailed();
      lease.release();

      await pool.run((r) async => resourcesUsed.add(r));

      expect(resourcesUsed, [0, 1]);
    });

    test('does-not-couple-an-operation-to-a-slow-destroy', () async {
      final pool = _pool(
        maxConcurrentOperations: 1,
        maxIdleResources: 0,
        destroyGate: Completer<void>().future,
      );

      await expectLater(pool.run((_) async => 'done'), completion('done'));
    });

    test('terminate-waits-for-a-destroy-started-by-collection', () async {
      final gate = Completer<void>();
      final destroyed = <int>[];
      final pool = _pool(
        maxConcurrentOperations: 1,
        maxIdleResources: 0,
        destroyed: destroyed,
        destroyGate: gate.future,
      );

      await pool.run((_) async {});
      expect(destroyed, [0]);

      var terminated = false;
      final termination = pool.terminate().then((_) => terminated = true);
      await Future<void>.value();
      expect(terminated, isFalse, reason: 'destroy has not finished yet');

      gate.complete();
      await termination;
      expect(terminated, isTrue);
    });

    test('terminate-is-idempotent', () async {
      final destroyed = <int>[];
      final pool = _pool(maxConcurrentOperations: 2, destroyed: destroyed);
      final completer = Completer<void>();

      unawaited(pool.run((_) => completer.future));

      final first = pool.terminate();
      final second = pool.terminate();
      completer.complete();
      await Future.wait([first, second]);

      expect(destroyed, [0]); // Destroyed once, not once per terminate() call.
      expect(pool.size, 0);
    });

    test('terminate-twice-does-not-throw-concurrent-modification', () async {
      final pool = _pool(maxConcurrentOperations: 1);
      final completers = List.generate(2, (_) => Completer<void>());

      final ops = [
        pool.run((_) => completers[0].future),
        pool.run((_) => completers[1].future),
      ];
      await Future<void>.value();
      expect(pool.size, 2);

      final terminations = [pool.terminate(), pool.terminate()];
      for (final c in completers) {
        c.complete();
      }
      await Future.wait(ops);

      await expectLater(Future.wait(terminations), completes);
    });

    test('terminate-after-terminate-returns-immediately', () async {
      final destroyed = <int>[];
      final pool = _pool(maxConcurrentOperations: 1, destroyed: destroyed);

      await pool.run((_) async {});
      await pool.terminate();
      await pool.terminate();

      expect(destroyed, hasLength(lessThanOrEqualTo(1)));
    });

    test('waits-for-in-flight-operations-before-terminating', () async {
      final pool = _pool(maxConcurrentOperations: 1);
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
