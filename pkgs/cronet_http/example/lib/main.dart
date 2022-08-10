// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:cronet_http/cronet_client.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

void main() {
  late Client client;
  if (Platform.isIOS) {
    client = CronetClient();
  } else {
    client = IOClient();
  }

  runWithClient(() => runApp(const BookSearchApp()), () => client);
}

class Book {
  String title;
  String description;
  String imageUrl;

  Book(this.title, this.description, this.imageUrl);
}

class BookSearchApp extends StatelessWidget {
  const BookSearchApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const MaterialApp(
        // Remove the debug banner
        debugShowCheckedModeBanner: false,
        title: 'Book Search',
        home: HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Book> _books = [];

  @override
  void initState() {
    super.initState();
  }

  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _books = [];
      });
      return;
    }

    // `get` will use the `Client` configured in main.
    get(Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': query,
      'maxResults': '40',
      'printType': 'books'
    })).then((response) {
      final books = <Book>[];
      final jsonPayload = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

      if (jsonPayload['items'] is List<dynamic>) {
        final items =
            (jsonPayload['items'] as List).cast<Map<String, Object?>>();

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
                  (volumeInfo['imageLinks'] as Map)['smallThumbnail']
                      as String));
            }
          }
        }
      }
      setState(() {
        _books = books;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Book Search'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const SizedBox(
                height: 20,
              ),
              TextField(
                onChanged: _runSearch,
                decoration: const InputDecoration(
                    labelText: 'Search', suffixIcon: Icon(Icons.search)),
              ),
              const SizedBox(
                height: 20,
              ),
              Expanded(
                child: _books.isNotEmpty
                    ? BookList(_books)
                    : const Text(
                        'No results found',
                        style: TextStyle(fontSize: 24),
                      ),
              ),
            ],
          ),
        ),
      );
}

class BookList extends StatefulWidget {
  final List<Book> books;
  const BookList(this.books, {Key? key}) : super(key: key);

  @override
  State<BookList> createState() => _BookListState();
}

class _BookListState extends State<BookList> {
  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: widget.books.length,
        itemBuilder: (context, index) => Card(
          key: ValueKey(widget.books[index].title),
          child: ListTile(
            leading: Image.network(widget.books[index].imageUrl),
            title: Text(widget.books[index].title),
            subtitle: Text(widget.books[index].description),
          ),
        ),
      );
}
