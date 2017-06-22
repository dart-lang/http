// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'client.dart';
import 'response.dart';

/// A typedef for [Cascade._shouldCascade].
typedef bool _ShouldCascade(Response response);

/// A helper that calls several clients in sequence and returns the first
/// acceptable response.
///
/// By default, a response is considered acceptable if it has a status other
/// than 404 or 405; other statuses indicate that the client understood the
/// request.
///
/// If all clients return unacceptable responses, the final response will be
/// returned.
///
///     var client = new Cascade()
///         .add(webSocketHandler)
///         .add(staticFileHandler)
///         .add(application)
///         .client;
class Cascade {
  /// The function used to determine whether the cascade should continue on to
  /// the next client.
  final _ShouldCascade _shouldCascade;

  final Cascade _parent;
  final Client _client;

  /// Creates a new, empty cascade.
  ///
  /// If [statusCodes] is passed, responses with those status codes are
  /// considered unacceptable. If [shouldCascade] is passed, responses for which
  /// it returns `true` are considered unacceptable. [statusCode] and
  /// [shouldCascade] may not both be passed.
  Cascade({Iterable<int> statusCodes, bool shouldCascade(Response response)})
      : _shouldCascade = _computeShouldCascade(statusCodes, shouldCascade),
        _parent = null,
        _client = null {
    if (statusCodes != null && shouldCascade != null) {
      throw new ArgumentError("statusCodes and shouldCascade may not both be "
          "passed.");
    }
  }

  Cascade._(this._parent, this._client, this._shouldCascade);

  /// Returns a new cascade with [client] added to the end.
  ///
  /// [client] will only be called if all previous clients in the cascade
  /// return unacceptable responses.
  Cascade add(Client client) => new Cascade._(this, client, _shouldCascade);

  /// Exposes this cascade as a single client.
  ///
  /// This client will call each inner client in the cascade until one returns
  /// an acceptable response, and return that. If no inner clients return an
  /// acceptable response, this will return the final response.
  Client get client {
    if (_client == null) {
      throw new StateError("Can't get a client for a cascade with no inner "
          "clients.");
    }

    return new Client.handler((request) async {
      if (_parent._client == null) return _client.send(request);

      return _parent.client.send(request).then((response) =>
          _shouldCascade(response)
              ? _client.send(request)
              : new Future<Response>.value(response));
    }, onClose: () {
      _client.close();

      // Go up the chain closing the individual clients
      var parent = _parent;

      while (parent != null) {
        parent._client?.close();

        parent = parent._parent;
      }
    });
  }
}

/// Computes the [Cascade._shouldCascade] function based on the user's
/// parameters.
_ShouldCascade _computeShouldCascade(
    Iterable<int> statusCodes, bool shouldCascade(Response response)) {
  if (shouldCascade != null) return shouldCascade;
  if (statusCodes == null) statusCodes = [404, 405];
  statusCodes = statusCodes.toSet();
  return (response) => statusCodes.contains(response.statusCode);
}
