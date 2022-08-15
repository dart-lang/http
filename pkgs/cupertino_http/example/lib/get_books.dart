import 'dart:convert';
import 'package:http/http.dart';

import 'book.dart';

Future<List<Book>> getBooks(String query) async {
  final response = await get(
    Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes',
      {'q': query, 'maxResults': '40', 'printType': 'books'},
    ),
  );

  final books = <Book>[];
  final jsonPayload = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

  if (jsonPayload['items'] is List<dynamic>) {
    final items = (jsonPayload['items'] as List).cast<Map<String, Object?>>();

    for (final item in items) {
      if (item.containsKey('volumeInfo')) {
        final volumeInfo = item['volumeInfo'] as Map;
        if (volumeInfo['title'] is String &&
            volumeInfo['description'] is String &&
            volumeInfo['imageLinks'] is Map &&
            (volumeInfo['imageLinks'] as Map)['smallThumbnail'] is String) {
          books.add(Book(
              volumeInfo['title'] as String,
              volumeInfo['description'] as String,
              (volumeInfo['imageLinks'] as Map)['smallThumbnail'] as String));
        }
      }
    }
  }

  return books;
}
