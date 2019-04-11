---
name: An HTTP request fails when made through this client.
about: You are attempting to make a GET or POST and getting an unexpected
  exception or status code.

---

**********************************************************
**This is not the repository you want to file issues in!**
**********************************************************

Note that a failing HTTP connection is almost certainly not caused by a bug in
package:http.

This package is a wrapper around the HttpClient from dart:io and HttpRequest
from dart:html. Before filing a bug here verify that the issue is not surfaced
when using those interfaces directly.

https://api.dartlang.org/stable/dart-io/HttpClient-class.html
https://api.dartlang.org/stable/dart-html/HttpRequest-class.html

# Common problems:

- A security policy prevents the connection.
- Running in an emulator that does not have outside internet access.
- Using Android and not requesting internet access in the manifest.
  https://github.com/flutter/flutter/issues/29688


None of these problems are influenced by the code in this repo.

# Diagnosing:

- Attempt the request outside of Dart, for instance in a browser or with `curl`.
- Attempt the request with the dart:io or dart:html equivalent code paths.
