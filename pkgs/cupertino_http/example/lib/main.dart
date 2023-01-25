// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

import 'book.dart';

void main() {
  var clientFactory = Client.new; // The default Client.
  if (Platform.isIOS || Platform.isMacOS) {
    clientFactory = CupertinoClient.defaultSessionConfiguration.call;
  }
  runWithClient(() => runApp(const BookSearchApp()), clientFactory);
}

class BookSearchApp extends StatelessWidget {
  const BookSearchApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        // Remove the debug banner.
        debugShowCheckedModeBanner: false,
        title: 'Book Search',
        home: HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Book>? _books;

  @override
  void initState() {
    super.initState();
  }

  // Get the list of books matching `query`.
  // The `get` call will automatically use the `client` configurated in `main`.
  Future<List<Book>> _findMatchingBooks(String query) async {
    final response = await get(
      Uri.https(
        'www.googleapis.com',
        '/books/v1/volumes',
        {'q': query, 'maxResults': '40', 'printType': 'books'},
      ),
    );

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    return Book.listFromJson(json);
  }

  void _runSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _books = null;
      });
      return;
    }

    final books = await _findMatchingBooks(query);
    setState(() {
      _books = books;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResult = _books == null
        ? const Text('Please enter a query', style: TextStyle(fontSize: 24))
        : _books!.isNotEmpty
            ? BookList(_books!)
            : const Text('No results found', style: TextStyle(fontSize: 24));

    return Scaffold(
      appBar: AppBar(title: const Text('Book Search')),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(
              onChanged: _runSearch,
              decoration: const InputDecoration(
                labelText: 'Search',
                suffixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: searchResult),
          ],
        ),
      ),
    );
  }
}

class BookList extends StatefulWidget {
  final List<Book> books;
  const BookList(this.books, {super.key});

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
            leading: CachedNetworkImage(
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                imageUrl:
                    widget.books[index].imageUrl.replaceFirst('http', 'https')),
            title: Text(widget.books[index].title),
            subtitle: Text(widget.books[index].description),
          ),
        ),
      );
}
