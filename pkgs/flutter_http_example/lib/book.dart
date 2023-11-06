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
          if (volumeInfo
              case {
                'title': final String title,
                'description': final String description,
                'imageLinks': {'smallThumbnail': final String thumbnail}
              }){
            books.add(Book(title, description, thumbnail));
          }
        }
      }
    }

    return books;
  }
}
