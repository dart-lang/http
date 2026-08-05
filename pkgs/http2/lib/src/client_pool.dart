// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

class _PooledResource<T> {
  _PooledResource(this.future);
  final Future<T> future;
  int inFlight = 0;
  bool failed = false;

  /// The resolved value of [future], once available - kept so scheduling can
  /// consult the resource itself from paths that are synchronous by design.
  T? value;
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
  int get opCount => _resources.map((resource) => resource.inFlight).sum;

  /// Runs [operation] on an available (or newly created) resource.
  Future<R> run<R>(Future<R> Function(T resource) operation) async {
    if (_terminated) {
      throw StateError('This pool has already been terminated.');
    }

    final pooled = _acquire();
    pooled.inFlight++;
    try {
      final resource = pooled.value ??= await pooled.future;
      return await operation(resource);
    } catch (_) {
      pooled.failed = true;
      rethrow;
    } finally {
      pooled.inFlight--;
      if (_terminated) {
        _maybeCompleteDrain();
      } else {
        _collectIfIdle(pooled);
      }
    }
  }

  // Synchronous (no `await`), so concurrent calls can't race each other
  // into both creating a resource before either sees the other's.
  _PooledResource<T> _acquire() {
    _PooledResource<T>? selected;
    for (final resource in _resources) {
      if (resource.failed) continue;
      if (resource.inFlight < _capacityOf(resource) &&
          (selected == null || resource.inFlight > selected.inFlight)) {
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
        : min(maxConcurrentOperations, limit);
  }

  void _collectIfIdle(_PooledResource<T> resource) {
    if (resource.inFlight > 0) return;
    if (!resource.failed && !_hasExcessIdleCapacity(resource)) return;

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
    // Called synchronously when the value is already known, so a resource is
    // observably destroyed as soon as it leaves the pool.
    final done =
        value != null ? _destroy(value) : resource.future.then(_destroy);
    // Best-effort: a failure here must neither shadow the caller's own request
    // error nor surface as an unhandled async error.
    final tracked = done.catchError((Object _) {});
    _pendingDestroys.add(tracked);
    unawaited(tracked.whenComplete(() => _pendingDestroys.remove(tracked)));
  }

  // Measured in [resource]'s own capacity, so that resources holding fewer
  // operations than [maxConcurrentOperations] aren't collected as excess the
  // moment they drain - which would churn a connection per operation.
  bool _hasExcessIdleCapacity(_PooledResource<T> resource) {
    // Failed resources are never routed new work by _acquire(), so they
    // contribute no real idle capacity.
    final idleCapacity =
        _resources
            .map(
              (other) => other.failed ? 0 : _capacityOf(other) - other.inFlight,
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

    // Snapshotted and cleared before any `await`, so nothing is iterating
    // _resources across a suspension point.
    final resources = _resources.toList();
    _resources.clear();
    for (final resource in resources) {
      _startDestroy(resource);
    }
    // Includes destroys started earlier by _collectIfIdle, so that when this
    // completes every resource really has been destroyed.
    await Future.wait(_pendingDestroys.toList());
  }
}
