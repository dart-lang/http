import 'dart:convert' as convert;

import 'package:http/http.dart' as http;
import 'package:http/http_headers_utils/http_headers.dart';

void main(List<String> arguments) async {
  // This example uses the Google Books API to search for books about http.
  // https://developers.google.com/books/docs/overview
  var url =
      Uri.https('www.googleapis.com', '/books/v1/volumes', {'q': '{http}'});

  // Fetching data from the Uri using HttpHeaders' ContentType's class,
  // Navigate to lib/http_headers_utils to know more..
  await http.get(url,headers: {
    HttpHeaders.contentTypeHeader : ContentType.json.primaryType
  }).then((response) => print(response.body));

  // Await the http get response, then decode the json-formatted response.
  var response = await http.get(url);
  if (response.statusCode == 200) {
    var jsonResponse =
        convert.jsonDecode(response.body) as Map<String, dynamic>;
    var itemCount = jsonResponse['totalItems'];
    print('Number of books about http: $itemCount.');
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }
}
