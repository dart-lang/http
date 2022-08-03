import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';

import 'package:cupertino_http/cupertino_client.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

void main() {
  runApp(const BookSearchApp());
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
  Widget build(BuildContext context) {
    return const MaterialApp(
      // Remove the debug banner
      debugShowCheckedModeBanner: false,
      title: 'Book Search',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Book> _books = [];

  @override
  initState() {
    super.initState();
  }

  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _books = [];
      });
      return;
    }

    // TODO: Set this up in main when runWithClient is released with package
    // HTTP.
    late Client client;
    if (Platform.isIOS) {
      client = CupertinoClient.defaultSessionConfiguration();
    } else {
      client = IOClient();
    }
    client
        .get(Uri.https('www.googleapis.com', '/books/v1/volumes',
            {'q': query, 'maxResults': '40', 'printType': 'books'}))
        .then((response) {
      final List<Book> books = [];
      final jsonPayload = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

      if (jsonPayload['items'] is List<dynamic>) {
        final items = jsonPayload['items'] as List<dynamic>;

        for (final Map item in items) {
          if (item.containsKey('volumeInfo')) {
            final volumeInfo = item['volumeInfo'] as Map;
            if (volumeInfo['title'] is String &&
                volumeInfo['description'] is String &&
                volumeInfo['imageLinks'] is Map &&
                volumeInfo['imageLinks']['smallThumbnail'] is String) {
              books.add(Book(volumeInfo['title'], volumeInfo['description'],
                  volumeInfo['imageLinks']['smallThumbnail']));
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
  Widget build(BuildContext context) {
    return Scaffold(
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
              onChanged: (value) => _runSearch(value),
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
}

class BookList extends StatefulWidget {
  final List<Book> books;
  const BookList(this.books, {Key? key}) : super(key: key);

  @override
  State<BookList> createState() => _BookListState();
}

class _BookListState extends State<BookList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
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
}
