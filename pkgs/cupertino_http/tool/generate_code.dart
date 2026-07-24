// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:ffigen/ffigen.dart';
import 'package:logging/logging.dart';

class NativeCupertinoHttpVisitor extends Visitor {
  static const includedInterfaces = {
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
  };

  static const includedProtocols = {
    'NSURLSessionDataDelegate',
    'NSURLSessionDownloadDelegate',
    'NSURLSessionWebSocketDelegate',
  };

  static const includedEnums = {
    'NSHTTPCookieAcceptPolicy',
    'NSURLRequestCachePolicy',
    'NSURLRequestNetworkServiceType',
    'NSURLSessionMultipathServiceType',
    'NSURLSessionResponseDisposition',
    'NSURLSessionTaskState',
    'NSURLSessionWebSocketMessageType',
    'NSURLSessionWebSocketCloseCode',
  };

  const NativeCupertinoHttpVisitor();

  @override
  void visitObjCInterface(ObjCInterface node) {
    if (includedInterfaces.contains(node.originalName)) {
      node.isExcluded = false;
      for (final method in node.methods) {
        if (node.originalName == 'NSURLResponse' &&
            method.originalName ==
                'initWithURL:MIMEType:'
                    'expectedContentLength:textEncodingName:') {
          method.name = 'initWithUrlAndMIMEType';
          for (final p in method.parameters) {
            if (p.originalName == 'expectedContentLength') p.name = 'length';
            if (p.originalName == 'textEncodingName') p.name = 'name';
          }
        } else if (node.originalName == 'NSHTTPURLResponse' &&
            method.originalName ==
                'initWithURL:statusCode:HTTPVersion:headerFields:') {
          method.name = 'initWithURLAndStatusCode';
        }
      }
    } else {
      node.isExcluded = true;
    }
  }

  @override
  void visitObjCProtocol(ObjCProtocol node) {
    if (includedProtocols.contains(node.originalName)) {
      node.isExcluded = false;
    } else {
      node.isExcluded = true;
    }
  }

  @override
  void visitEnum(EnumClass node) {
    if (includedEnums.contains(node.originalName)) {
      node.isExcluded = false;
      if (node.originalName == 'NSURLSessionWebSocketCloseCode') {
        node.style = EnumStyle.intConstants;
      }
    } else {
      node.isExcluded = true;
    }
  }
}

final generator = FfiGenerator(
  headers: Headers(
    entryPoints: [
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSURLCache.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSURLRequest.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSURLSession.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSURL.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSLock.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSProgress.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSURLResponse.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSHTTPCookieStorage.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSOperation.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSError.h',
      ),
      Uri.file(
        '$macSdkPath/System/Library/Frameworks/Foundation.framework/Headers/NSDictionary.h',
      ),
    ],
  ),
  enums: const Enums(silenceWarning: true),
  objectiveC: const ObjectiveC(),
  visitors: const [ExcludeAllVisitor(), NativeCupertinoHttpVisitor()],
  output: Output(
    dartFile: Uri.file('lib/src/native_cupertino_bindings.dart'),
    objectiveCFile: Uri.file('src/native_cupertino_bindings.m'),
    commentType: const CommentType(CommentStyle.any, CommentLength.full),
    preamble: '''
// ignore_for_file: always_specify_types
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: unused_element
// ignore_for_file: unused_field
// ignore_for_file: return_of_invalid_type
''',
  ),
);

void main() {
  final logger = Logger('ffigen');
  logger.onRecord.listen((record) {
    print('[${record.level.name}] ${record.message}');
  });
  generator.generate(logger: logger);
}
