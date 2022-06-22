// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:native_library/src/target.dart';
import 'package:native_library/src/embedder.dart';

/// The location for native libraries if shipped with the package.
///
/// The standardized location for native libraries shipped with a package
/// as binary is:
/// `package root`/native/lib/[target]/
///
/// Only available in [StandaloneRuntimeMode.jit] and
/// [FlutterRuntimeMode.test]. In all other modes, the native libraries should
/// have been packaged with the app.
Uri sharedLibrariesLocationShipped(String packageName, {Target? target}) {
  if (target == null) {
    target = Target.current;
  }
  final packageUri = packageLocation(packageName);
  return packageUri.resolve('native/lib/$target/');
}

/// The location for native libraries when built with `bin/setup.dart`.
///
/// The standardized location for native libraries built by the dependees of
/// a package shipping native source code is:
/// `dependee root`/.dart_tool/[packageName]/native/lib/[target]/
///
/// Only available in [StandaloneRuntimeMode.jit] and
/// [FlutterRuntimeMode.test]. In all other modes, the native libraries should
/// have been packaged with the app.
Uri sharedLibrariesLocationBuilt(String packageName, {Target? target}) {
  if (target == null) {
    target = Target.current;
  }
  return packageConfigSync.resolve('package/$packageName/native/lib/$target/');
}
