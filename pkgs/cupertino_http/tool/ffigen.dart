// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:ffigen/ffigen.dart';

FfiGenerator getConfig(Uri packageRoot) {
  const headers = [
    'NSURLAuthenticationChallenge.h',
    'NSURLCache.h',
    'NSURLCredential.h',
    'NSURLProtectionSpace.h',
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
  ];
  return FfiGenerator(
    input: Input(
      entryPoints: [
        for (final header in headers)
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
      commentType: const CommentType(CommentStyle.any, CommentLength.full),
    ),
    visitors: [
      Visitor(
        objCInterface: (node) {
          const included = {
            'NSCondition',
            'NSHTTPURLResponse',
            'NSMutableURLRequest',
            'NSOperationQueue',
            'NSURLAuthenticationChallenge',
            'NSURLCache',
            'NSURLCredential',
            'NSURLProtectionSpace',
            'NSURLRequest',
            'NSURLResponse',
            'NSURLSession',
            'NSURLSessionConfiguration',
            'NSURLSessionDownloadTask',
            'NSURLSessionTask',
            'NSURLSessionWebSocketMessage',
            'NSURLSessionWebSocketTask',
          };
          node.isIncluded = included.contains(node.originalName);
        },
        objCProtocol: (node) {
          const included = {
            'NSURLSessionDataDelegate',
            'NSURLSessionDownloadDelegate',
            'NSURLSessionWebSocketDelegate',
          };
          node.isIncluded = included.contains(node.originalName);
        },
        func: (node) {
          // The minimal set of Security functions needed to inspect and
          // evaluate `NSURLProtectionSpace.serverTrust`.
          const included = {
            'SecCertificateCopyData',
            'SecCertificateCopySubjectSummary',
            'SecCertificateCreateWithData',
            'SecTrustCopyCertificateChain',
            'SecTrustEvaluateWithError',
            'SecTrustGetNetworkFetchAllowed',
            'SecTrustSetAnchorCertificates',
            'SecTrustSetAnchorCertificatesOnly',
            'SecTrustSetNetworkFetchAllowed',
          };
          node.isIncluded = included.contains(node.originalName);
        },
        global: (node) {
          const included = {
            'NSURLAuthenticationMethodClientCertificate',
            'NSURLAuthenticationMethodDefault',
            'NSURLAuthenticationMethodHTMLForm',
            'NSURLAuthenticationMethodHTTPBasic',
            'NSURLAuthenticationMethodHTTPDigest',
            'NSURLAuthenticationMethodNegotiate',
            'NSURLAuthenticationMethodNTLM',
            'NSURLAuthenticationMethodServerTrust',
          };
          node.isIncluded = included.contains(node.originalName);
        },
        typealias: (node) {
          // The underlying opaque structs (e.g. `__SecTrust`) are private in
          // the generated bindings so generate public typedefs that can be
          // named in `cupertino_api.dart`.
          const included = {
            'CFArrayRef',
            'CFDataRef',
            'CFErrorRef',
            'SecCertificateRef',
            'SecTrustRef',
          };
          if (included.contains(node.originalName)) {
            node.isIncluded = TypealiasInclude.always;
          }
        },
        enumClass: (node) {
          const included = {
            'NSHTTPCookieAcceptPolicy',
            'NSURLCredentialPersistence',
            'NSURLRequestCachePolicy',
            'NSURLRequestNetworkServiceType',
            'NSURLSessionAuthChallengeDisposition',
            'NSURLSessionMultipathServiceType',
            'NSURLSessionResponseDisposition',
            'NSURLSessionTaskState',
            'NSURLSessionWebSocketCloseCode',
            'NSURLSessionWebSocketMessageType',
          };
          node.isIncluded = included.contains(node.originalName);

          const intEnums = {'NSURLSessionWebSocketCloseCode'};
          node.style = intEnums.contains(node.originalName)
              ? .intConstants
              : null;
        },
      ),
    ],
  );
}

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
