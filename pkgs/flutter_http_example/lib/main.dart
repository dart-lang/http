// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

import 'book.dart';
import 'http_client_factory.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart' as http_factory;

void main() {
  // `runWithClient` is used to control which `package:http` `Client` is used
  // when the `Client` constructor is called. This method allows you to choose
  // the `Client` even when the package that you are using does not offer
  // explicit parameterization.
  //
  // However, `runWithClient` does not work with Flutter tests. See
  // https://github.com/flutter/flutter/issues/96939.
  //
  // Use `package:provider` and `runWithClient` together so that tests and
  // unparameterized `Client` usages both work.
  runWithClient(
      () => runApp(Provider<Client>(
          create: (_) => http_factory.httpClient(),
          child: const BookSearchApp(),
          dispose: (_, client) => client.close())),
      http_factory.httpClient);
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
  String? _lastQuery;
  late Client _client;

  @override
  void initState() {
    super.initState();
    _client = context.read<Client>();
  }

  // Get the list of books matching `query`.
  // The `get` call will automatically use the `client` configurated in `main`.
  Future<List<Book>> _findMatchingBooks(String query) async {
    final response = await _client.get(
      Uri.https(
        'www.googleapis.com',
        '/books/v1/volumes',
        {'q': query, 'maxResults': '20', 'printType': 'books'},
      ),
    );

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    return Book.listFromJson(json);
  }

  void _runSearch(String query) async {
    _lastQuery = query;
    if (query.isEmpty) {
      setState(() {
        _books = null;
      });
      return;
    }

    final books = await _findMatchingBooks(query);
    // Avoid the situation where a slow-running query finishes late and
    // replaces newer search results.
    if (query != _lastQuery) return;
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
