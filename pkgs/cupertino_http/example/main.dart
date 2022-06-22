import 'dart:convert';
import 'dart:math';

import 'package:cupertino_http/cupertino_http.dart';

void main() {
  final url =
      Uri.https('www.googleapis.com', '/books/v1/volumes', {'q': '{http}'});
  final session = URLSession.sharedSession();
  session.dataTaskWithCompletionHandler(URLRequest.fromUrl(url),
      (data, response, error) {
    if (error != null) {
      print('Requested failed with: $error');
      return;
    }
    if (response!.statusCode != 200) {
      print('Request failed with status: ${response.statusCode}');
      return;
    }
    final jsonResponse =
        jsonDecode(utf8.decode(data!.bytes)) as Map<String, dynamic>;
    final itemCount = jsonResponse['totalItems'] as int;
    print('Number of books about http: $itemCount.');
    for (var i = 0; i < min(itemCount, 10); ++i) {
      // ignore: avoid_dynamic_calls
      print(jsonResponse['items'][i]['volumeInfo']['title']);
    }
  }).resume();
}