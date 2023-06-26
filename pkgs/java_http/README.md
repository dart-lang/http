A Dart package for making HTTP requests using native Java APIs
([java.net.HttpURLConnection](https://docs.oracle.com/javase/8/docs/api/java/net/HttpURLConnection.html)).

Using native Java APIs has several advantages on Android:

 * Support for `KeyStore` `PrivateKey`s ([#50669](https://github.com/dart-lang/sdk/issues/50669))
 * Support for the system proxy ([#50434](https://github.com/dart-lang/sdk/issues/50434))
 * Support for user-installed certificates ([#50435](https://github.com/dart-lang/sdk/issues/50435))

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