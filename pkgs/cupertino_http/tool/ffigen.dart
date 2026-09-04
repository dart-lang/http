// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:ffigen/ffigen.dart';

FfiGenerator getConfig(Uri packageRoot) => FfiGenerator(
  input: Input(
    entryPoints: [
      for (final header in const [
        'NSURLCache.h',
        'NSURLRequest.h',
        'NSURLSession.h',
        'NSURL.h',
        'NSLock.h',
        'NSProgress.h',
        'NSURLResponse.h',
        'NSHTTPCookieStorage.h',
        'NSOperation.h',
        'NSError.h',
        'NSDictionary.h',
      ])
        macSdkUri.resolve(
          'System/Library/Frameworks/Foundation.framework/Headers/$header',
        ),
    ],
  ),
  objectiveC: const ObjectiveC(),
  output: Output(
    dart: DartOutput(
      path: packageRoot.resolve('lib/src/native_cupertino_bindings.dart'),
    ),
    objectiveCFile: packageRoot.resolve('src/native_cupertino_bindings.m'),
    preamble: '''
// ignore_for_file: always_specify_types
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: unused_element
// ignore_for_file: unused_field
// ignore_for_file: return_of_invalid_type
''',
    commentType: const CommentType(CommentStyle.any, CommentLength.full),
  ),
  visitors: [
    Visitor(
      objCInterface: (node) {
        node.isIncluded = const {
          'NSCondition',
          'NSHTTPURLResponse',
          'NSMutableURLRequest',
          'NSOperationQueue',
          'NSURLCache',
          'NSURLRequest',
          'NSURLResponse',
          'NSURLSession',
          'NSURLSessionConfiguration',
          'NSURLSessionDownloadTask',
          'NSURLSessionTask',
          'NSURLSessionWebSocketMessage',
          'NSURLSessionWebSocketTask',
        }.contains(node.originalName);
      },
      objCMethod: (node) {
        final interfaceRenames = const {
          // TODO(brianquinlan): Remove this when
          // https://github.com/dart-lang/native/issues/2419 is fixed.
          'NSURLResponse': {
            'initWithURL:MIMEType:expectedContentLength:textEncodingName:':
                'initWithUrlAndMIMEType',
          },
          'NSHTTPURLResponse': {
            'initWithURL:statusCode:HTTPVersion:headerFields:':
                'initWithURLAndStatusCode',
          },
        }[node.parent.originalName];
        if (interfaceRenames != null) {
          final rename = interfaceRenames[node.originalName];
          if (rename != null) {
            node.name = rename;
          }
        }
      },
      objCProtocol: (node) {
        node.isIncluded = const {
          'NSURLSessionDataDelegate',
          'NSURLSessionDownloadDelegate',
          'NSURLSessionWebSocketDelegate',
        }.contains(node.originalName);
      },
      enumClass: (node) {
        final isIntEnum = const {
          'NSURLSessionWebSocketCloseCode',
        }.contains(node.originalName);
        if (isIntEnum) {
          node
            ..isIncluded = true
            ..style = EnumStyle.intConstants;
        } else {
          node.isIncluded = const {
            'NSHTTPCookieAcceptPolicy',
            'NSURLRequestCachePolicy',
            'NSURLRequestNetworkServiceType',
            'NSURLSessionMultipathServiceType',
            'NSURLSessionResponseDisposition',
            'NSURLSessionTaskState',
            'NSURLSessionWebSocketMessageType',
          }.contains(node.originalName);
        }
      },
    ),
  ],
);

Uri _findPackageRoot() {
  if (Platform.script.isScheme('file')) {
    var dir = Directory.fromUri(Platform.script).parent;
    while (dir.path != dir.parent.path) {
      final pubspec = File.fromUri(dir.uri.resolve('pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (content.contains('name: cupertino_http\n') ||
            content.contains('name: cupertino_http\r\n')) {
          return dir.uri;
        }
      }
      dir = dir.parent;
    }
  }
  return Directory.current.uri;
}

Future<void> main() async {
  final packageRoot = _findPackageRoot();
  await getConfig(packageRoot).generate();
}
