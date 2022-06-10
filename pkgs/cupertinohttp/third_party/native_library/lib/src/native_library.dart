import 'package:native_library/src/abi.dart';
import 'package:native_library/src/embedder.dart';

/// The location for native libraries if shipped with the package.
///
/// The standardized location for native libraries shipped with a package
/// as binary is:
/// `package root`/native/lib/[abi]/
///
/// Only available in [StandaloneRuntimeMode.jit] and
/// [FlutterRuntimeMode.test]. In all other modes, the native libraries should
/// have been packaged with the app.
Uri sharedLibrariesLocationShipped(String packageName, {Abi? abi}) {
  if (abi == null) {
    abi = Abi.current;
  }
  final packageUri = packageLocation(packageName);
  return packageUri.resolve('native/lib/$abi/');
}

/// The location for native libraries when built with `bin/setup.dart`.
///
/// The standardized location for native libraries built by the dependees of
/// a package shipping native source code is:
/// `dependee root`/.dart_tool/[packageName]/native/lib/[abi]/
///
/// Only available in [StandaloneRuntimeMode.jit] and
/// [FlutterRuntimeMode.test]. In all other modes, the native libraries should
/// have been packaged with the app.
Uri sharedLibrariesLocationBuilt(String packageName, {Abi? abi}) {
  if (abi == null) {
    abi = Abi.current;
  }
  return packageConfigSync.resolve('package/$packageName/native/lib/$abi/');
}
