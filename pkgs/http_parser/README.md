[![Pub Package](https://img.shields.io/pub/v/http_parser.svg)](https://pub.dartlang.org/packages/http_parser)
[![package publisher](https://img.shields.io/pub/publisher/http_parser.svg)](https://pub.dev/packages/http_parser/publisher)

`http_parser` is a platform-independent package for parsing and serializing
various HTTP-related formats. It's designed to be usable on both the browser
and the server, and thus avoids referencing any types from `dart:io` or
`package:web`.

## Features

* Support for parsing and formatting dates according to [HTTP/1.1][2616], the
  HTTP/1.1 standard.

* A `MediaType` class that represents an HTTP media type, as used in `Accept`
  and `Content-Type` headers. This class supports both parsing and formatting
  media types according to [HTTP/1.1][2616].

* An `AuthenticationChallenge` class that represents a challenge in a
  `WWW-Authenticate` header. This class supports parsing challenges according to
  [RFC 2617][2617].

* A `CaseInsensitiveMap` class that represents a map with case-insensitive
  string keys, such as HTTP header names.

* A `chunkedCoding` codec that encodes and decodes the
  [chunked transfer coding][chunked].

`WebSocketChannel`, which was previously part of this package, has been moved to
[`package:web_socket_channel`][web_socket_channel].

[2616]: https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html
[2617]: https://tools.ietf.org/html/rfc2617
[chunked]: https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.6.1
[web_socket_channel]: https://pub.dev/packages/web_socket_channel
