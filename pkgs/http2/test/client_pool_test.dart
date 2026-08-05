// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http2/src/client_pool.dart';
import 'package:test/test.dart';

ClientPool<int> _pool({
  required int maxConcurrentOperations,
  int maxIdleResources = 1,
  int? Function(int resource)? concurrencyLimitOf,
  List<int>? destroyed,
}) {
  var nextId = 0;
  return ClientPool<int>(
    () async => nextId++,
    maxConcurrentOperations: maxConcurrentOperations,
    maxIdleResources: maxIdleResources,
    destroy: (resource) async => destroyed?.add(resource),
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
      // The pool would allow 10 per resource; each resource only allows 2.
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
      // The limit is only visible once resource 0 has been created, so let it
      // resolve before dispatching work that has to respect it.
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
      // A resource permitting more than the pool does must not raise the cap.
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
      // Stands in for a server revising SETTINGS_MAX_CONCURRENT_STREAMS: the
      // limit starts at 2 and drops to 1.
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
      // Regression test for collecting a healthy resource as "excess idle"
      // because its real capacity is below maxConcurrentOperations, which
      // would churn one resource per operation.
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
      // Resource 1 is still busy, so resource 0 going idle doesn't make it
      // excess - measuring its spare capacity against maxConcurrentOperations
      // rather than its own limit of 1 would collect it here.
      expect(destroyed, isEmpty);
      expect(pool.size, 2);

      completers[1].complete();
      await second;

      // maxIdleResources is 1 and each resource holds 1, so exactly one of
      // the two is excess - not both, and not one per operation.
      expect(destroyed, hasLength(1));
      expect(pool.size, 1);
    });

    test('rejects-operations-after-terminate', () async {
      final pool = _pool(maxConcurrentOperations: 1);

      await pool.terminate();

      expect(() => pool.run((_) async {}), throwsA(isA<StateError>()));
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
