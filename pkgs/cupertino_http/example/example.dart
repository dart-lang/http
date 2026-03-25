import 'dart:convert' as convert;

import 'package:cupertino_http/cupertino_http.dart';

void main(List<String> arguments) async {
  // This example uses the Google Books API to search for books about http.
  // https://developers.google.com/books/docs/overview

  // For a complete example of using `package:cupertino_http` in a Flutter
  // application, see:
  // https://github.com/dart-lang/http/tree/master/pkgs/flutter_http_example
  final client = CupertinoClient.defaultSessionConfiguration();
  final url = Uri.https('www.googleapis.com', '/books/v1/volumes', {
    'q': '{http}',
  });

  // Await the http get response, then decode the json-formatted response.
  final response = await client.get(url);
  if (response.statusCode == 200) {
    var jsonResponse =
        convert.jsonDecode(response.body) as Map<String, dynamic>;
    var itemCount = jsonResponse['totalItems'];
    print('Number of books about http: $itemCount.');
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }
  client.close();
}
