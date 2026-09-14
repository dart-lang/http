// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A pool of HTTP/2 connections, each carrying several streams at once.
///
/// Create one by saying how a connection is dialed and how many streams it may
/// carry:
///
/// ```dart
/// final pool = ClientPool(
///   () => dial(host, port),
///   maxConcurrentStreams: 100,
/// );
/// ```
///
/// Use [ClientPool.run] when the connection is free again as soon as the
/// returned future completes:
///
/// ```dart
/// final result = await pool.run((connection) => send(connection, request));
/// ```
///
/// Use [ClientPool.acquire] when the connection is still in use after that
/// future completes - an HTTP/2 response, for example, is returned as soon as
/// its headers arrive but keeps its stream open while the body is delivered.
/// The caller then owns the slot until it releases the lease:
///
/// ```dart
/// final lease = await pool.acquire();
/// try {
///   return startStreaming(lease.connection, onDone: lease.release);
/// } catch (_) {
///   lease.release();
///   rethrow;
/// }
/// ```
///
/// Finally, [ClientPool.terminate] waits for in-flight streams and then closes
/// every connection.
library;

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'connection.dart';

/// One pooled connection, and the bookkeeping the pool keeps for it.
class _PooledConnection {
  _PooledConnection(this.creation);

  /// Completes with the connection once it has been dialed.
  final Future<ClientConnection> creation;

  /// The resolved value of [creation], once available.
  ///
  /// Kept because scheduling decisions are synchronous by design, so they
  /// need to consult the connection itself without waiting on [creation].
  ClientConnection? value;

  /// How many streams are running on this connection right now.
  int inFlightCount = 0;

  /// Whether the pool should stop routing new work to this connection.
  ///
  /// Set when dialing it failed, and also by [PoolLease.markFailed] when a
  /// stream on it failed - either way it is no longer trusted, and it is
  /// closed once the streams it is still carrying finish.
  bool createFailed = false;
}

/// A claim on one stream slot of a pooled connection.
///
/// Held from [ClientPool.acquire] until [release], which lets a slot outlive
/// the future that produced it - an HTTP/2 response, for instance, is returned
/// as soon as its headers arrive but keeps its stream open until the body ends.
class PoolLease {
  PoolLease._(this._pool, this._pooled, this.connection);

  final ClientPool _pool;
  final _PooledConnection _pooled;

  /// The connection this slot was claimed on.
  final ClientConnection connection;

  var _released = false;

  /// Stops the pool routing new work to this connection.
  void markFailed() => _pooled.createFailed = true;

  /// Gives the slot back. Idempotent, so it is safe to call from several
  /// terminal paths that may race.
  void release() {
    if (_released) return;
    _released = true;
    _pool._freeSlot(_pooled);
  }
}

/// A pool of HTTP/2 connections.
///
/// Packs streams onto the most-loaded connection under its capacity (rather
/// than spreading them evenly), dials another once existing ones are full,
/// stops routing new work to a connection once a stream on it throws, and
/// closes idle connections past [maxIdleConnections].
///
/// Capacity is [maxConcurrentStreams], lowered to whatever limit a server
/// advertises for its own connection.
class ClientPool {
  ClientPool(
    Future<ClientConnection> Function() dial, {
    required this.maxConcurrentStreams,
    this.maxIdleConnections = 1,
  }) : _dial = dial;

  final Future<ClientConnection> Function() _dial;

  final int maxConcurrentStreams;
  final int maxIdleConnections;

  final _connections = <_PooledConnection>[];
  final _pendingCloses = <Future<void>>{};
  var _terminated = false;
  Completer<void>? _drained;
  Future<void>? _termination;

  /// The number of connections currently pooled.
  int get size => _connections.length;

  /// The number of in-flight streams across every connection. For testing.
  @visibleForTesting
  int get opCount => _connections.map((c) => c.inFlightCount).sum;

  /// Claims a slot on an available (or newly dialed) connection.
  ///
  /// The caller owns the returned lease and must [PoolLease.release] it on
  /// every path, errors included, or the slot leaks and [terminate] never
  /// drains. Prefer [run] unless the slot has to outlive the future that
  /// produced whatever the caller is returning.
  Future<PoolLease> acquire() async {
    if (_terminated) {
      throw StateError('This pool has already been terminated.');
    }

    while (true) {
      final pooled = _select();
      pooled.inFlightCount++;
      final PoolLease lease;
      try {
        lease = PoolLease._(
          this,
          pooled,
          pooled.value ??= await pooled.creation,
        );
      } catch (_) {
        pooled.createFailed = true;
        _freeSlot(pooled);
        rethrow;
      }

      if (pooled.inFlightCount <= _capacityOf(pooled)) return lease;
      lease.release();
    }
  }

  /// Returns one slot to [pooled], closing the connection if it has gone idle.
  void _freeSlot(_PooledConnection pooled) {
    pooled.inFlightCount--;
    if (_terminated) {
      _maybeCompleteDrain();
    } else {
      _closeIfIdle(pooled);
    }
  }

  /// Runs [operation] on an available (or newly dialed) connection.
  Future<R> run<R>(
    Future<R> Function(ClientConnection connection) operation,
  ) async {
    final lease = await acquire();
    try {
      return await operation(lease.connection);
    } catch (_) {
      lease.markFailed();
      rethrow;
    } finally {
      lease.release();
    }
  }

  // Synchronous (no `await`), so concurrent calls can't race each other
  // into both dialing a connection before either sees the other's.
  _PooledConnection _select() {
    _PooledConnection? selected;
    for (final pooled in _connections) {
      if (pooled.createFailed) continue;
      // Pick the available connection with the most inflight requests. This
      // makes it more likely that fewer active connections need to be
      // maintained.
      if (pooled.inFlightCount < _capacityOf(pooled) &&
          (selected == null || pooled.inFlightCount > selected.inFlightCount)) {
        selected = pooled;
      }
    }
    if (selected != null) return selected;

    final pooled = _PooledConnection(_dial());
    _connections.add(pooled);
    return pooled;
  }

  /// How many streams [pooled] may carry at once.
  ///
  /// A connection that hasn't been dialed yet, or whose server advertises no
  /// limit of its own, is held to [maxConcurrentStreams].
  int _capacityOf(_PooledConnection pooled) {
    final connection = pooled.value;
    if (connection == null) return maxConcurrentStreams;
    final limit = connection.peerMaxConcurrentStreams;
    // Floored at one: a server advertising zero would otherwise make the
    // connection unusable, and acquire()'s confirm loop would spin.
    return limit == null
        ? maxConcurrentStreams
        : max(1, min(maxConcurrentStreams, limit));
  }

  void _closeIfIdle(_PooledConnection pooled) {
    if (pooled.inFlightCount > 0) return;
    if (!pooled.createFailed && !_hasExcessIdleCapacity(pooled)) return;

    _connections.remove(pooled);
    _startClose(pooled);
  }

  /// Starts closing [pooled] without waiting for it, so that a stream is never
  /// held up by its connection's teardown - `finish()` itself waits on every
  /// other stream still running on that connection.
  ///
  /// Tracked in [_pendingCloses] so [terminate] can still promise that every
  /// connection has actually been closed by the time it completes.
  void _startClose(_PooledConnection pooled) {
    final connection = pooled.value;
    final done =
        connection != null
            ? connection.finish()
            : pooled.creation.then((c) => c.finish());
    final tracked = done.then<void>((_) {}).catchError((Object _) {});
    _pendingCloses.add(tracked);
    unawaited(tracked.whenComplete(() => _pendingCloses.remove(tracked)));
  }

  bool _hasExcessIdleCapacity(_PooledConnection pooled) {
    final idleCapacity =
        _connections
            .map(
              (other) =>
                  other.createFailed
                      ? 0
                      : _capacityOf(other) - other.inFlightCount,
            )
            .sum;
    return idleCapacity > maxIdleConnections * _capacityOf(pooled);
  }

  void _maybeCompleteDrain() {
    if (_drained case final drained?
        when !drained.isCompleted && opCount == 0) {
      drained.complete();
    }
  }

  /// Waits for in-flight streams to finish, then closes every connection in
  /// the pool. No further streams can be opened afterward.
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
    // _connections across a suspension point.
    final connections = _connections.toList();
    _connections.clear();
    for (final pooled in connections) {
      _startClose(pooled);
    }
    await Future.wait(_pendingCloses.toList());
  }
}
