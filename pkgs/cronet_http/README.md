An Android Flutter plugin that provides access to the
[Cronet](https://developer.android.com/guide/topics/connectivity/cronet/reference/org/chromium/net/package-summary)
HTTP client.

Cronet is available as part of
[Google Play Services](https://developers.google.com/android/guides/overview). 

This package depends on
[Google Play Services](https://developers.google.com/android/guides/overview)
for its Cronet implementation.
[`package:cronet_http_embedded`](https://pub.dev/packages/cronet_http_embedded)
is functionally identical to this package but embeds Cronet directly instead
of relying on
[Google Play Services](https://developers.google.com/android/guides/overview).

## Status: Experimental

**NOTE**: This package is currently experimental and published under the
[labs.dart.dev](https://dart.dev/dart-team-packages) pub publisher in order to
solicit feedback. 

For packages in the labs.dart.dev publisher we generally plan to either graduate
the package into a supported publisher (dart.dev, tools.dart.dev) after a period
of feedback and iteration, or discontinue the package. These packages have a
much higher expected rate of API and breaking changes.

Your feedback is valuable and will help us evolve this package. 
For general feedback and suggestions please comment in the
[feedback issue](https://github.com/dart-lang/http/issues/764).
For bugs, please file an issue in the 
[bug tracker](https://github.com/dart-lang/http/issues).
