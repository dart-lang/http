// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

import 'native_cupertino_bindings.dart' as ncb;

const _packageName = 'cupertino_http';
const _libName = _packageName;

/// Access to symbols that are linked into the process.
///
/// The "Foundation" framework is linked to Dart so no additional
/// libraries need to be loaded to access those symbols.
final ncb.NativeCupertinoHttp linkedLibs = () {
  if (Platform.isMacOS || Platform.isIOS) {
    final lib = DynamicLibrary.process();
    return ncb.NativeCupertinoHttp(lib);
  }
  throw UnsupportedError(
      'Platform ${Platform.operatingSystem} is not supported');
}();

/// Access to symbols that are available in the cupertino_http helper shared
/// library.
final ncb.NativeCupertinoHttp helperLibs = _loadHelperLibrary();

DynamicLibrary _loadHelperDynamicLibrary() {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }

  throw UnsupportedError(
      'Platform ${Platform.operatingSystem} is not supported');
}

ncb.NativeCupertinoHttp _loadHelperLibrary() {
  final lib = _loadHelperDynamicLibrary();

  final initializeApi = lib.lookupFunction<IntPtr Function(Pointer<Void>),
      int Function(Pointer<Void>)>('Dart_InitializeApiDL');
  final initializeResult = initializeApi(NativeApi.initializeApiDLData);
  if (initializeResult != 0) {
    throw StateError('failed to init API.');
  }

  return ncb.NativeCupertinoHttp(lib);
}

String? toStringOrNull(ncb.NSString? s) {
  if (s == null) {
    return null;
  }

  return s.toString();
}

/// Converts a NSDictionary containing NSString keys and NSString values into
/// an equivalent map.
Map<String, String> stringDictToMap(ncb.NSDictionary d) {
  // TODO(https://github.com/dart-lang/ffigen/issues/374): Make this
  // function type safe. Currently it will unconditionally cast both keys and
  // values to NSString with a likely crash down the line if that isn't their
  // true types.
  final m = <String, String>{};

  final keys = ncb.NSArray.castFrom(d.allKeys!);
  for (var i = 0; i < keys.count; ++i) {
    final nsKey = keys.objectAtIndex_(i);
    final key = toStringOrNull(ncb.NSString.castFrom(nsKey))!;
    final value =
        toStringOrNull(ncb.NSString.castFrom(d.objectForKey_(nsKey)))!;
    m[key] = value;
  }

  return m;
}
