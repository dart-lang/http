import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';

Client http_client() {
  if (Platform.isIOS || Platform.isMacOS) {
    return CupertinoClient.defaultSessionConfiguration();
  }
  return Client();
}
