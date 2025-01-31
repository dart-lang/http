// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:http_image_provider/http_image_provider.dart';
import 'package:provider/provider.dart';

import 'book.dart';

void main() {
  final Client httpClient;
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
        userAgent: 'Book Agent');
    httpClient = CronetClient.fromCronetEngine(engine, closeEngine: true);
  } else {
    httpClient = IOClient(HttpClient()..userAgent = 'Book Agent');
  }

  runApp(Provider<Client>(
      create: (_) => httpClient,
      child: const BookSearchApp(),
      dispose: (_, client) => client.close()));
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
  // The `get` call will automatically use the `client` configured in `main`.
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
            leading: Image(
                image: HttpImageProvider(
                    widget.books[index].imageUrl.replace(scheme: 'https'),
                    client: context.read<Client>())),
            title: Text(widget.books[index].title),
            subtitle: Text(widget.books[index].description),
          ),
        ),
      );
}
