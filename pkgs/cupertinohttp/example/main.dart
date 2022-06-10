import 'dart:convert';
import 'dart:math';

import 'package:cupertinohttp/cupertinohttp.dart';

void main() {
  final url =
      Uri.https('www.googleapis.com', '/books/v1/volumes', {'q': '{http}'});
  final session = URLSession.sharedSession();
  final task = session.dataTaskWithCompletionHandler(URLRequest.fromUrl(url),
      (data, response, error) {
    if (error == null) {
      if (response!.statusCode == 200) {
        final jsonResponse =
            jsonDecode(utf8.decode(data!.bytes)) as Map<String, dynamic>;
        final itemCount = jsonResponse['totalItems'];
        print('Number of books about http: $itemCount.');
        for (var i = 0; i < min(itemCount, 10); ++i) {
          print(jsonResponse['items'][i]['volumeInfo']['title']);
        }
      } else {
        print('Request failed with status: ${response.statusCode}');
      }
    } else {
      print('Requested failed with: $error');
    }
  });
  task.resume();
}
