// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class Book {
  String title;
  String description;
  String imageUrl;

  Book(this.title, this.description, this.imageUrl);

  static List<Book> listFromJson(Map<dynamic, dynamic> json) {
    final books = <Book>[];

    if (json['items'] case final List jsonItems) {
      final items = jsonItems.cast<Map<String, Object?>>();

      for (final item in items) {
        if (item case {'volumeInfo': final volumeInfo as Map}) {
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
}
