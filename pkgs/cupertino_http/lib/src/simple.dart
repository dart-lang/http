import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:objective_c/objective_c.dart' as objc;

import 'native_cupertino_bindings.dart' as ncb;

void doHTTPRequest() {
  final queue = ncb.NSOperationQueue.new1()
    ..maxConcurrentOperationCount = 1
    ..name = 'cupertino_http.NSURLSessionDelegateQueue'.toNSString();

  final protoBuilder = objc.ObjCProtocolBuilder();

  ncb.NSURLSessionDataDelegate.addToBuilderAsListener(
    protoBuilder,
    URLSession_dataTask_didReceiveResponse_completionHandler_:
        (session, dataTask, response, completionHandler) {
      final httpResponse = ncb.NSHTTPURLResponse.castFrom(response);

      print(
          'Got a response ${httpResponse.MIMEType.toString()} ${httpResponse.statusCode}, ${httpResponse.expectedContentLength}');
      completionHandler
          .call(ncb.NSURLSessionResponseDisposition.NSURLSessionResponseAllow);
    },
    URLSession_dataTask_didReceiveData_: (session, dataTask, data) {
      print('Do something with the data: ${data.length}');
    },
    /*
    URLSession_task_willPerformHTTPRedirection_newRequest_completionHandler_:
        (nsSession, nsTask, nsResponse, nsRequest, nsRequestCompleter) {
      print('redirect');
      nsRequestCompleter.call;
    },
    */
  );

  ncb.NSURLSessionDownloadDelegate.addToBuilderAsListener(protoBuilder,
      URLSession_downloadTask_didFinishDownloadingToURL_: (session, task, url) {
    print('Do something.');
  });
  final delegate = protoBuilder.build();

  final session =
      ncb.NSURLSession.sessionWithConfiguration_delegate_delegateQueue_(
          ncb.NSURLSessionConfiguration.getDefaultSessionConfiguration(),
          delegate,
          queue);
  session.dataTaskWithURL_(
      objc.NSURL.URLWithString_('https://www.google.com/'.toNSString())!)
    ..resume();
}
