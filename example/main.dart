import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

main(List<String> arguments) async {
  // This example uses the Google Books API to search for books about http.
  // https://developers.google.com/books/docs/overview
  var url = "https://www.googleapis.com/books/v1/volumes?q={http}";

  // Await the http get response, then decode the json-formatted responce.
  var response = await http.get(url);
  if (response.statusCode == 200) {
    var jsonResponse = convert.jsonDecode(response.body);
    var itemCount = jsonResponse['totalItems'];
    print("Number of books about http: $itemCount.");
  } else {
    print("Request failed with status: ${response.statusCode}.");
  }
}
