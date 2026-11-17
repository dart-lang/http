// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Starts two HTTP servers (`server1` and `server2`) and communicates over
/// [channel].
///
/// Channel protocol:
/// - On startup: sends `server1.port`, then `server2.port`.
/// - On non-`OPTIONS` request: sends
///   `['server1' | 'server2', method, body, headers]`.
/// - On receiving any message: closes both servers and exits.
///
/// `server1` routes:
///
/// | Request path       | Response                                         |
/// | :----------------- | :----------------------------------------------- |
/// | `/cross-port`      | `302` -> `http://localhost:<server2.port>/`      |
/// | `/cross-host`      | `302` -> `http://127.0.0.1:<server1.port>/`      |
/// | `/cross-host-301`  | `301` -> `http://127.0.0.1:<server2.port>/`      |
/// | `/cross-host-302`  | `302` -> `http://127.0.0.1:<server2.port>/`      |
/// | `/cross-host-303`  | `303` -> `http://127.0.0.1:<server2.port>/`      |
/// | `/cross-host-307`  | `307` -> `http://127.0.0.1:<server2.port>/`      |
/// | `/cross-host-308`  | `308` -> `http://127.0.0.1:<server2.port>/`      |
/// | `/cross-ping`      | `302` -> `http://127.0.0.1:<server2.port>/pong`  |
/// | `/cookie-ping`     | `/cross-ping` + `Set-Cookie`, to `/cookie-pong`  |
/// | `/relative`        | `302` -> `/`                                     |
/// | `/scheme-relative` | `302` -> `//127.0.0.1:<server1.port>/`           |
/// | `/loop`            | `302` -> `http://localhost:<server1.port>/loop`  |
/// | `/<n>` (n>1)       | `302` -> `http://localhost:<server1.port>/<n-1>` |
/// | `/1`               | `302` -> `http://localhost:<server1.port>/`      |
/// | `/`                | `200 OK`                                         |
///
/// `server2` routes:
///
/// | Request path       | Response                                         |
/// | :----------------- | :----------------------------------------------- |
/// | `/pong`            | `302` -> `http://localhost:<server1.port>/`      |
/// | `/cookie-pong`     | `/pong` + `Set-Cookie`                           |
/// | `/`                | `200 OK`                                         |
///
/// `/cookie-ping` sets the cookie `localhost-cookie=secret` and `/cookie-pong`
/// sets the cookie `loopback-cookie=secret`.
void hybridMain(StreamChannel<Object?> channel) async {
  late HttpServer server1;
  late HttpServer server2;

  server1 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
    ..listen((request) async {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      if (request.method == 'OPTIONS') {
        // Handle a CORS preflight request:
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#preflighted_requests
        request.response.headers
          ..set('Access-Control-Allow-Methods', 'GET, POST')
          ..set('Access-Control-Allow-Headers', '*, Authorization');
        unawaited(request.response.close());
        return;
      }

      final body = await utf8.decodeStream(request);
      final headers = <String, List<String>>{};
      request.headers.forEach((field, value) {
        headers[field] = value;
      });
      channel.sink.add(['server1', request.method, body, headers]);

      if (request.requestedUri.pathSegments.isEmpty) {
        unawaited(request.response.close());
      } else {
        switch (request.requestedUri.pathSegments.last) {
          case 'cross-port':
            unawaited(request.response
                .redirect(Uri.http('localhost:${server2.port}', '/')));
          case 'cross-host':
            unawaited(request.response
                .redirect(Uri.http('127.0.0.1:${server1.port}', '/')));
          case 'cross-host-301':
            unawaited(request.response.redirect(
                Uri.http('127.0.0.1:${server2.port}', '/'),
                status: HttpStatus.movedPermanently));
          case 'cross-host-302':
            unawaited(request.response.redirect(
                Uri.http('127.0.0.1:${server2.port}', '/'),
                status: HttpStatus.found));
          case 'cross-host-303':
            unawaited(request.response.redirect(
                Uri.http('127.0.0.1:${server2.port}', '/'),
                status: HttpStatus.seeOther));
          case 'cross-host-307':
            unawaited(request.response.redirect(
                Uri.http('127.0.0.1:${server2.port}', '/'),
                status: HttpStatus.temporaryRedirect));
          case 'cross-host-308':
            unawaited(request.response.redirect(
                Uri.http('127.0.0.1:${server2.port}', '/'),
                status: HttpStatus.permanentRedirect));
          case 'cross-ping':
            unawaited(request.response
                .redirect(Uri.http('127.0.0.1:${server2.port}', '/pong')));
          case 'cookie-ping':
            request.response.headers
                .add('set-cookie', 'localhost-cookie=secret');
            unawaited(request.response.redirect(
                Uri.http('127.0.0.1:${server2.port}', '/cookie-pong')));
          case 'relative':
            request.response
              ..statusCode = HttpStatus.found
              ..headers.set('location', '/');
            unawaited(request.response.close());
          case 'scheme-relative':
            request.response
              ..statusCode = HttpStatus.found
              ..headers.set('location', '//127.0.0.1:${server1.port}/');
            unawaited(request.response.close());
          case 'loop':
            unawaited(request.response
                .redirect(Uri.http('localhost:${server1.port}', '/loop')));
          case final segment:
            final n = int.parse(segment);
            final nextPath = n - 1 == 0 ? '' : '${n - 1}';
            unawaited(request.response
                .redirect(Uri.http('localhost:${server1.port}', '/$nextPath')));
        }
      }
    });

  server2 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
    ..listen((request) async {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      if (request.method == 'OPTIONS') {
        // Handle a CORS preflight request:
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#preflighted_requests
        request.response.headers
          ..set('Access-Control-Allow-Methods', 'GET, POST')
          ..set('Access-Control-Allow-Headers', '*, Authorization');
        unawaited(request.response.close());
        return;
      }

      final body = await utf8.decodeStream(request);
      final headers = <String, List<String>>{};
      request.headers.forEach((field, value) {
        headers[field] = value;
      });
      channel.sink.add(['server2', request.method, body, headers]);

      if (request.requestedUri.pathSegments.isEmpty) {
        unawaited(request.response.close());
      } else if (request.requestedUri.pathSegments.last == 'pong') {
        unawaited(request.response
            .redirect(Uri.http('localhost:${server1.port}', '/')));
      } else if (request.requestedUri.pathSegments.last == 'cookie-pong') {
        request.response.headers.add('set-cookie', 'loopback-cookie=secret');
        unawaited(request.response
            .redirect(Uri.http('localhost:${server1.port}', '/')));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        unawaited(request.response.close());
      }
    });

  channel.sink.add(server1.port);
  channel.sink.add(server2.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server1.close());
  unawaited(server2.close());
}
