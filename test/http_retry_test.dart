// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:http_retry/http_retry.dart';
import 'package:test/test.dart';

void main() {
  group("doesn't retry when", () {
    test("a request has a non-503 error code", () async {
      var client = RetryClient(
          MockClient(expectAsync1((_) async => Response("", 502), count: 1)));
      var response = await client.get("http://example.org");
      expect(response.statusCode, equals(502));
    });

    test("a request doesn't match when()", () async {
      var client = RetryClient(
          MockClient(expectAsync1((_) async => Response("", 503), count: 1)),
          when: (_) => false);
      var response = await client.get("http://example.org");
      expect(response.statusCode, equals(503));
    });

    test("retries is 0", () async {
      var client = RetryClient(
          MockClient(expectAsync1((_) async => Response("", 503), count: 1)),
          retries: 0);
      var response = await client.get("http://example.org");
      expect(response.statusCode, equals(503));
    });
  });

  test("retries on a 503 by default", () async {
    var count = 0;
    var client = RetryClient(
        MockClient(expectAsync1((request) async {
          count++;
          return count < 2 ? Response("", 503) : Response("", 200);
        }, count: 2)),
        delay: (_) => Duration.zero);

    var response = await client.get("http://example.org");
    expect(response.statusCode, equals(200));
  });

  test("retries on any request where when() returns true", () async {
    var count = 0;
    var client = RetryClient(
        MockClient(expectAsync1((request) async {
          count++;
          return Response("", 503,
              headers: {"retry": count < 2 ? "true" : "false"});
        }, count: 2)),
        when: (response) => response.headers["retry"] == "true",
        delay: (_) => Duration.zero);

    var response = await client.get("http://example.org");
    expect(response.headers, containsPair("retry", "false"));
    expect(response.statusCode, equals(503));
  });

  test("retries on any request where whenError() returns true", () async {
    var count = 0;
    var client = RetryClient(
        MockClient(expectAsync1((request) async {
          count++;
          if (count < 2) throw StateError("oh no");
          return Response("", 200);
        }, count: 2)),
        whenError: (error, _) =>
            error is StateError && error.message == "oh no",
        delay: (_) => Duration.zero);

    var response = await client.get("http://example.org");
    expect(response.statusCode, equals(200));
  });

  test("doesn't retry a request where whenError() returns false", () async {
    var client = RetryClient(
        MockClient(expectAsync1((request) async => throw StateError("oh no"))),
        whenError: (error, _) => error == "oh yeah",
        delay: (_) => Duration.zero);

    expect(client.get("http://example.org"),
        throwsA(isStateError.having((e) => e.message, 'message', "oh no")));
  });

  test("retries three times by default", () async {
    var client = RetryClient(
        MockClient(expectAsync1((_) async => Response("", 503), count: 4)),
        delay: (_) => Duration.zero);
    var response = await client.get("http://example.org");
    expect(response.statusCode, equals(503));
  });

  test("retries the given number of times", () async {
    var client = RetryClient(
        MockClient(expectAsync1((_) async => Response("", 503), count: 13)),
        retries: 12,
        delay: (_) => Duration.zero);
    var response = await client.get("http://example.org");
    expect(response.statusCode, equals(503));
  });

  test("waits 1.5x as long each time by default", () {
    FakeAsync().run((fake) {
      var count = 0;
      var client = RetryClient(MockClient(expectAsync1((_) async {
        count++;
        if (count == 1) {
          expect(fake.elapsed, equals(Duration.zero));
        } else if (count == 2) {
          expect(fake.elapsed, equals(Duration(milliseconds: 500)));
        } else if (count == 3) {
          expect(fake.elapsed, equals(Duration(milliseconds: 1250)));
        } else if (count == 4) {
          expect(fake.elapsed, equals(Duration(milliseconds: 2375)));
        }

        return Response("", 503);
      }, count: 4)));

      expect(client.get("http://example.org"), completes);
      fake.elapse(Duration(minutes: 10));
    });
  });

  test("waits according to the delay parameter", () {
    FakeAsync().run((fake) {
      var count = 0;
      var client = RetryClient(
          MockClient(expectAsync1((_) async {
            count++;
            if (count == 1) {
              expect(fake.elapsed, equals(Duration.zero));
            } else if (count == 2) {
              expect(fake.elapsed, equals(Duration.zero));
            } else if (count == 3) {
              expect(fake.elapsed, equals(Duration(seconds: 1)));
            } else if (count == 4) {
              expect(fake.elapsed, equals(Duration(seconds: 3)));
            }

            return Response("", 503);
          }, count: 4)),
          delay: (requestCount) => Duration(seconds: requestCount));

      expect(client.get("http://example.org"), completes);
      fake.elapse(Duration(minutes: 10));
    });
  });

  test("waits according to the delay list", () {
    FakeAsync().run((fake) {
      var count = 0;
      var client = RetryClient.withDelays(
          MockClient(expectAsync1((_) async {
            count++;
            if (count == 1) {
              expect(fake.elapsed, equals(Duration.zero));
            } else if (count == 2) {
              expect(fake.elapsed, equals(Duration(seconds: 1)));
            } else if (count == 3) {
              expect(fake.elapsed, equals(Duration(seconds: 61)));
            } else if (count == 4) {
              expect(fake.elapsed, equals(Duration(seconds: 73)));
            }

            return Response("", 503);
          }, count: 4)),
          [Duration(seconds: 1), Duration(minutes: 1), Duration(seconds: 12)]);

      expect(client.get("http://example.org"), completes);
      fake.elapse(Duration(minutes: 10));
    });
  });

  test("calls onRetry for each retry", () async {
    var count = 0;
    var client = RetryClient(
        MockClient(expectAsync1((_) async => Response("", 503), count: 3)),
        retries: 2,
        delay: (_) => Duration.zero,
        onRetry: expectAsync3((request, response, retryCount) {
          expect(request.url, equals(Uri.parse("http://example.org")));
          expect(response.statusCode, equals(503));
          expect(retryCount, equals(count));
          count++;
        }, count: 2));
    var response = await client.get("http://example.org");
    expect(response.statusCode, equals(503));
  });

  test("copies all request attributes for each attempt", () async {
    var client = RetryClient.withDelays(
        MockClient(expectAsync1((request) async {
          expect(request.contentLength, equals(5));
          expect(request.followRedirects, isFalse);
          expect(request.headers, containsPair("foo", "bar"));
          expect(request.maxRedirects, equals(12));
          expect(request.method, equals("POST"));
          expect(request.persistentConnection, isFalse);
          expect(request.url, equals(Uri.parse("http://example.org")));
          expect(request.body, equals("hello"));
          return Response("", 503);
        }, count: 2)),
        [Duration.zero]);

    var request = Request("POST", Uri.parse("http://example.org"));
    request.body = "hello";
    request.followRedirects = false;
    request.headers["foo"] = "bar";
    request.maxRedirects = 12;
    request.persistentConnection = false;

    var response = await client.send(request);
    expect(response.statusCode, equals(503));
  });
}
