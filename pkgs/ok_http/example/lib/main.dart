// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:http_image_provider/http_image_provider.dart';
import 'package:ok_http/ok_http.dart';
import 'package:provider/provider.dart';
import 'package:web_socket/web_socket.dart';

import 'book.dart';

void main() {
  final Client httpClient;
  if (Platform.isAndroid) {
    httpClient = OkHttpClient();
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
  int _selectedIndex = 1;
  final _labels = ['HTTP', 'WebSocket'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title:
                Text(_selectedIndex == 0 ? 'Book Search' : 'WebSocket Echo')),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (value) => setState(() {
            _selectedIndex = value;
          }),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.cloud_outlined),
              activeIcon: const Icon(Icons.cloud),
              label: _labels[0],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.swap_vert_circle_outlined),
              activeIcon: const Icon(Icons.swap_vert_circle),
              label: _labels[1],
            ),
          ],
        ),
        body: _selectedIndex == 0 ? const BookSearch() : const WebSocketEcho());
  }
}

class BookSearch extends StatefulWidget {
  const BookSearch({super.key});

  @override
  State<BookSearch> createState() => _BookSearchState();
}

class _BookSearchState extends State<BookSearch> {
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

    return Padding(
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
                image: HttpImage(
                    widget.books[index].imageUrl.replace(scheme: 'https'),
                    client: context.read<Client>())),
            title: Text(widget.books[index].title),
            subtitle: Text(widget.books[index].description),
          ),
        ),
      );
}

class WebSocketEcho extends StatefulWidget {
  const WebSocketEcho({super.key});

  @override
  State<WebSocketEcho> createState() => _WebSocketEchoState();
}

class _WebSocketEchoState extends State<WebSocketEcho> {
  final List<List> _messages = [];
  final msgController = TextEditingController();

  late WebSocket _webSocket;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: ElevatedButton(
                      onPressed: () async {
                        try {
                          _webSocket = await OkHttpWebSocket.connect(
                              Uri.parse('wss://echo.websocket.org'));
                        } on WebSocketException catch (e) {
                          print('Error connecting to WebSocket: ${e.message}');
                          return;
                        }

                        _webSocket.events.listen((event) {
                          setState(() {
                            switch (event) {
                              case TextDataReceived(text: final text):
                                _messages.add([text, false]);
                                break;
                              case CloseReceived():
                                _messages.add(['Connection closed', false]);
                              default:
                                _messages.add(
                                    ['Unknown message received $event', false]);
                            }
                          });
                        });
                      },
                      child: const Text('Connect'))),
              const SizedBox(width: 16),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () => _webSocket.close(),
                      child: const Text('Disconnect'))),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: msgController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                  ),
                ),
              ),
              ElevatedButton(
                  onPressed: () {
                    _webSocket.sendText(msgController.text);

                    setState(() {
                      _messages.add([msgController.text, true]);
                    });
                  },
                  child: const Text('Send')),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
              child: ListView.builder(
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_messages[index][0] as String),
                trailing: Icon(_messages[index][1] as bool
                    ? Icons.upload
                    : Icons.download),
              );
            },
            itemCount: _messages.length,
          )),
        ],
      ),
    );
  }
}
