import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cupertinohttp/cupertinoclient.dart';

void main() async {
  var client = CupertinoClient.defaultSessionConfiguration();
  final response = await client.get(
      Uri.https('www.googleapis.com', '/books/v1/volumes', {'q': '{http}'}));
  if (response.statusCode != 200) {
    throw HttpException('bad response: ${response.statusCode}');
  }

  final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

  final itemCount = decodedResponse['totalItems'];
  print('Number of books about http: $itemCount.');
  for (var i = 0; i < min(itemCount, 10); ++i) {
    print(decodedResponse['items'][i]['volumeInfo']['title']);
  }
}
