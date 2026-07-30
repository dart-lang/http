// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

class _PooledResource<T> {
  _PooledResource(this.future);
  final Future<T> future;
  int inFlight = 0;
  bool failed = false;
}

/// A pool of resources of type [T].
///
/// Packs load onto the most-full resource under [maxConcurrentOperations]
/// (rather than spreading evenly across resources), opens a new resource
/// once existing ones are full, stops routing new work to a resource once an
/// operation on it throws, and garbage-collects idle resources past
/// [maxIdleResources].
class ClientPool<T> {
  ClientPool(
    Future<T> Function() create, {
    required this.maxConcurrentOperations,
    required Future<void> Function(T resource) destroy,
    this.maxIdleResources = 1,
  }) : _create = create,
       _destroy = destroy;

  final Future<T> Function() _create;
  final Future<void> Function(T resource) _destroy;
  final int maxConcurrentOperations;
  final int maxIdleResources;

  final _resources = <_PooledResource<T>>[];
  var _terminated = false;
  Completer<void>? _drained;

  /// The number of resources currently in the pool. For testing.
  int get size => _resources.length;

  /// The number of in-flight operations across every resource. For testing.
  int get opCount =>
      _resources.fold(0, (total, resource) => total + resource.inFlight);

  /// Runs [operation] on an available (or newly created) resource.
  Future<R> run<R>(Future<R> Function(T resource) operation) async {
    if (_terminated) {
      throw StateError('This pool has already been terminated.');
    }

    final pooled = _acquire();
    pooled.inFlight++;
    try {
      return await operation(await pooled.future);
    } catch (_) {
      pooled.failed = true;
      rethrow;
    } finally {
      pooled.inFlight--;
      if (_terminated) {
        _maybeCompleteDrain();
      } else {
        await _collectIfIdle(pooled);
      }
    }
  }

  // Synchronous (no `await`), so concurrent calls can't race each other
  // into both creating a resource before either sees the other's.
  _PooledResource<T> _acquire() {
    _PooledResource<T>? selected;
    for (final resource in _resources) {
      if (resource.failed) continue;
      if (resource.inFlight < maxConcurrentOperations &&
          (selected == null || resource.inFlight > selected.inFlight)) {
        selected = resource;
      }
    }
    if (selected != null) return selected;

    final resource = _PooledResource<T>(_create());
    _resources.add(resource);
    return resource;
  }

  Future<void> _collectIfIdle(_PooledResource<T> resource) async {
    if (resource.inFlight > 0) return;
    if (!resource.failed && !_hasExcessIdleCapacity) return;

    _resources.remove(resource);
    try {
      await _destroy(await resource.future);
    } catch (_) {
      // Best-effort: a failure here must not shadow the caller's own
      // request error, since this runs inside run()'s finally block.
    }
  }

  bool get _hasExcessIdleCapacity {
    final idleCapacity = _resources.fold(
      0,
      (total, resource) =>
          total + (maxConcurrentOperations - resource.inFlight),
    );
    return idleCapacity > maxIdleResources * maxConcurrentOperations;
  }

  void _maybeCompleteDrain() {
    final drained = _drained;
    if (drained != null && !drained.isCompleted && opCount == 0) {
      drained.complete();
    }
  }

  /// Waits for in-flight operations to finish, then destroys every
  /// resource in the pool. No further operations can run afterward.
  Future<void> terminate() async {
    _terminated = true;

    if (opCount > 0) {
      _drained = Completer<void>();
      await _drained!.future;
    }

    for (final resource in _resources) {
      try {
        await _destroy(await resource.future);
      } catch (_) {
        // Best-effort: one resource failing to close shouldn't stop the
        // rest from being destroyed.
      }
    }
    _resources.clear();
  }
}
