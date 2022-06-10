// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

import 'package:native_library/native_library.dart';

import 'native_cupertino_bindings.dart' as ncb;

const _packageName = "cupertinohttp";
const _libName = _packageName;

/// Access to symbols that are linked into the process. The "Foundation"
/// framework is linked to Dart so no additional libraries need to be loaded
/// to access those symbols.
late ncb.NativeCupertinoHttp linkedLibs = () {
  final lib = DynamicLibrary.process();
  return ncb.NativeCupertinoHttp(lib);
}();

/// Access to symbols that are available in the cupertinohttp helper shared
/// library.
late ncb.NativeCupertinoHttp helperLibs = _loadHelperLibrary();

DynamicLibrary _loadHelperDynamicLibrary() {
  DynamicLibrary? _jit() {
    if (Platform.isMacOS) {
      final Uri dylibPath = sharedLibrariesLocationBuilt(_packageName)
          .resolve('lib$_libName.dylib');
      final File file = File.fromUri(dylibPath);
      if (!file.existsSync()) {
        throw "Dynamic library '${dylibPath.toFilePath()}' does not exist.";
      }
      return DynamicLibrary.open(dylibPath.path);
    }
    return null;
  }

  switch (Embedders.current) {
    case Embedder.flutter:
      switch (FlutterRuntimeModes.current) {
        case FlutterRuntimeMode.app:
          if (Platform.isMacOS || Platform.isIOS) {
            return DynamicLibrary.open('$_libName.framework/$_libName');
          }
          break;
        case FlutterRuntimeMode.test:
          final DynamicLibrary? result = _jit();
          if (result != null) {
            return result;
          }
          break;
      }
      break;
    case Embedder.standalone:
      switch (StandaloneRuntimeModes.current) {
        case StandaloneRuntimeMode.jit:
          final DynamicLibrary? result = _jit();
          if (result != null) {
            return result;
          }
          break;
        case StandaloneRuntimeMode.executable:
          // When running from executable, we expect the person assembling the
          // final executable to locate the dynamic library next to the
          // executable.
          if (Platform.isMacOS) {
            return DynamicLibrary.open('lib$_libName.dylib');
          }
          break;
      }
  }
  throw UnsupportedError('Unimplemented!');
}

ncb.NativeCupertinoHttp _loadHelperLibrary() {
  final lib = _loadHelperDynamicLibrary();

  final int Function(Pointer<Void>) initializeApi = lib.lookupFunction<
      IntPtr Function(Pointer<Void>),
      int Function(Pointer<Void>)>("Dart_InitializeApiDL");
  final int initializeResult = initializeApi(NativeApi.initializeApiDLData);
  if (initializeResult != 0) {
    throw 'failed to init API.';
  }

  return ncb.NativeCupertinoHttp(lib);
}

// TODO(https://github.com/dart-lang/ffigen/issues/373): Change to
// ncb.NSString.
String? toStringOrNull(ncb.NSObject? o) {
  if (o == null) {
    return null;
  }

  return ncb.NSString.castFrom(o).toString();
}

/// Converts a NSDictionary containing NSString keys and NSString values into
/// an equivalent map.
Map<String, String> stringDictToMap(ncb.NSDictionary d) {
  // TODO(https://github.com/dart-lang/ffigen/issues/374): Make this
  // function type safe. Currently it will unconditionally cast both keys and
  // values to NSString with a likely crash down the line if that isn't their
  // true types.
  final m = Map<String, String>();

  final keys = ncb.NSArray.castFrom(d.allKeys!);
  for (var i = 0; i < keys.count; ++i) {
    final nsKey = keys.objectAtIndex_(i);
    final key = toStringOrNull(nsKey)!;
    final value = toStringOrNull(d.objectForKey_(nsKey))!;
    m[key] = value;
  }

  return m;
}
