// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A pool of resources that can each carry several operations at once.
///
/// Create one by saying how a resource is made, how many operations it may
/// carry, and how it is disposed of:
///
/// ```dart
/// final pool = ClientPool<ClientConnection>(
///   () => dial(host, port),
///   maxConcurrentOperations: 100,
///   destroy: (connection) => connection.finish(),
///   // Optional: a resource may impose a lower limit of its own.
///   concurrencyLimitOf: (c) => c.peerMaxConcurrentStreams,
/// );
/// ```
///
/// Use [ClientPool.run] when the work finishes with the call:
///
/// ```dart
/// final result = await pool.run((connection) => send(connection, request));
/// ```
///
/// Use [ClientPool.acquire] when the resource stays busy after the call
/// returns - an HTTP/2 response, for example, arrives long after its headers
/// do. The caller then owns the slot until it releases the lease:
///
/// ```dart
/// final lease = await pool.acquire();
/// try {
///   return startStreaming(lease.value, onDone: lease.release);
/// } catch (_) {
///   lease.release();
///   rethrow;
/// }
/// ```
///
/// Finally, [ClientPool.terminate] waits for in-flight operations and then
/// disposes of every resource.
library;

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// One pooled resource, and the bookkeeping the pool keeps for it.
class _PooledResource<T> {
  _PooledResource(this.creation);

  /// Completes with the resource once it has been created.
  final Future<T> creation;

  /// The resolved value of [creation], once available.
  ///
  /// Kept because scheduling decisions are synchronous by design, so they
  /// need to consult the resource itself without waiting on [creation].
  T? value;

  /// How many operations are running on this resource right now.
  int inFlightCount = 0;

  /// Whether the pool should stop routing new work to this resource.
  ///
  /// Set both when creating it failed and when an operation on it failed -
  /// either way it is no longer trusted, and it is disposed of once the
  /// operations it is still carrying finish.
  bool isBroken = false;
}

/// A claim on one concurrency slot of a pooled resource.
///
/// Held from [ClientPool.acquire] until [release], which lets a slot outlive
/// the future that produced it - an HTTP/2 response, for instance, is returned
/// as soon as its headers arrive but keeps its stream open until the body ends.
class PoolLease<T> {
  PoolLease._(this._pool, this._resource, this.value);

  final ClientPool<T> _pool;
  final _PooledResource<T> _resource;

  /// The resource this slot was claimed on.
  final T value;

  var _released = false;

  /// Stops the pool routing new work to this resource.
  void markFailed() => _resource.isBroken = true;

  /// Gives the slot back. Idempotent, so it is safe to call from several
  /// terminal paths that may race.
  void release() {
    if (_released) return;
    _released = true;
    _pool._freeSlot(_resource);
  }
}

/// A pool of resources of type [T].
///
/// Packs load onto the most-full resource under its capacity (rather than
/// spreading evenly across resources), opens a new resource once existing
/// ones are full, stops routing new work to a resource once an operation on
/// it throws, and garbage-collects idle resources past [maxIdleResources].
///
/// Capacity is [maxConcurrentOperations], lowered to whatever limit a
/// resource reports for itself via `concurrencyLimitOf`.
class ClientPool<T> {
  ClientPool(
    Future<T> Function() create, {
    required this.maxConcurrentOperations,
    required Future<void> Function(T resource) destroy,
    this.maxIdleResources = 1,
    int? Function(T resource)? concurrencyLimitOf,
  }) : _create = create,
       _destroy = destroy,
       _concurrencyLimitOf = concurrencyLimitOf;

  final Future<T> Function() _create;
  final Future<void> Function(T resource) _destroy;

  /// Reports a resource's own concurrency limit, or `null` if it imposes none.
  ///
  /// Consulted on every scheduling decision rather than cached, so a limit
  /// the resource revises over its lifetime is picked up.
  final int? Function(T resource)? _concurrencyLimitOf;

  final int maxConcurrentOperations;
  final int maxIdleResources;

  final _resources = <_PooledResource<T>>[];
  final _pendingDestroys = <Future<void>>{};
  var _terminated = false;
  Completer<void>? _drained;
  Future<void>? _termination;

  /// The number of resources currently in the pool.
  int get size => _resources.length;

  /// The number of in-flight operations across every resource. For testing.
  @visibleForTesting
  int get opCount => _resources.map((resource) => resource.inFlightCount).sum;

  /// Claims a slot on an available (or newly created) resource.
  ///
  /// The caller owns the returned lease and must [PoolLease.release] it on
  /// every path, errors included, or the slot leaks and [terminate] never
  /// drains. Prefer [run] unless the slot has to outlive the future that
  /// produced whatever the caller is returning.
  Future<PoolLease<T>> acquire() async {
    if (_terminated) {
      throw StateError('This pool has already been terminated.');
    }

    while (true) {
      final pooled = _acquire();
      pooled.inFlightCount++;
      final PoolLease<T> lease;
      try {
        lease = PoolLease._(
          this,
          pooled,
          pooled.value ??= await pooled.creation,
        );
      } catch (_) {
        pooled.isBroken = true;
        _freeSlot(pooled);
        rethrow;
      }

      if (pooled.inFlightCount <= _capacityOf(pooled)) return lease;
      lease.release();
    }
  }

  /// Returns one slot to [resource], collecting it if it has gone idle.
  void _freeSlot(_PooledResource<T> resource) {
    resource.inFlightCount--;
    if (_terminated) {
      _maybeCompleteDrain();
    } else {
      _collectIfIdle(resource);
    }
  }

  /// Runs [operation] on an available (or newly created) resource.
  Future<R> run<R>(Future<R> Function(T resource) operation) async {
    final lease = await acquire();
    try {
      return await operation(lease.value);
    } catch (_) {
      lease.markFailed();
      rethrow;
    } finally {
      lease.release();
    }
  }

  // Synchronous (no `await`), so concurrent calls can't race each other
  // into both creating a resource before either sees the other's.
  _PooledResource<T> _acquire() {
    _PooledResource<T>? selected;
    for (final resource in _resources) {
      if (resource.isBroken) continue;
      // Pick the available connection with the most inflight requests. This
      // makes it more likely that fewer active connections need to be
      // maintained.
      if (resource.inFlightCount < _capacityOf(resource) &&
          (selected == null ||
              resource.inFlightCount > selected.inFlightCount)) {
        selected = resource;
      }
    }
    if (selected != null) return selected;

    final resource = _PooledResource<T>(_create());
    _resources.add(resource);
    return resource;
  }

  /// How many operations [resource] may run at once.
  ///
  /// A resource that hasn't been created yet, or that reports no limit of its
  /// own, is held to [maxConcurrentOperations].
  int _capacityOf(_PooledResource<T> resource) {
    final value = resource.value;
    final limitOf = _concurrencyLimitOf;
    if (value == null || limitOf == null) return maxConcurrentOperations;
    final limit = limitOf(value);
    return limit == null
        ? maxConcurrentOperations
        : max(1, min(maxConcurrentOperations, limit));
  }

  void _collectIfIdle(_PooledResource<T> resource) {
    if (resource.inFlightCount > 0) return;
    if (!resource.isBroken && !_hasExcessIdleCapacity(resource)) return;

    _resources.remove(resource);
    _startDestroy(resource);
  }

  /// Starts destroying [resource] without waiting for it, so that an operation
  /// is never held up by its resource's teardown - `destroy` may itself wait
  /// on unrelated work still running on that resource.
  ///
  /// Tracked in [_pendingDestroys] so [terminate] can still promise that every
  /// resource has actually been destroyed by the time it completes.
  void _startDestroy(_PooledResource<T> resource) {
    final value = resource.value;
    final done =
        value != null ? _destroy(value) : resource.creation.then(_destroy);
    final tracked = done.catchError((Object _) {});
    _pendingDestroys.add(tracked);
    unawaited(tracked.whenComplete(() => _pendingDestroys.remove(tracked)));
  }

  bool _hasExcessIdleCapacity(_PooledResource<T> resource) {
    final idleCapacity =
        _resources
            .map(
              (other) =>
                  other.isBroken ? 0 : _capacityOf(other) - other.inFlightCount,
            )
            .sum;
    return idleCapacity > maxIdleResources * _capacityOf(resource);
  }

  void _maybeCompleteDrain() {
    if (_drained case final drained?
        when !drained.isCompleted && opCount == 0) {
      drained.complete();
    }
  }

  /// Waits for in-flight operations to finish, then destroys every
  /// resource in the pool. No further operations can run afterward.
  ///
  /// Idempotent: concurrent and repeated calls all observe the same shutdown.
  Future<void> terminate() => _termination ??= _terminate();

  Future<void> _terminate() async {
    _terminated = true;

    if (opCount > 0) {
      _drained = Completer<void>();
      await _drained!.future;
    }

    final resources = _resources.toList();
    _resources.clear();
    for (final resource in resources) {
      _startDestroy(resource);
    }
    await Future.wait(_pendingDestroys.toList());
  }
}
