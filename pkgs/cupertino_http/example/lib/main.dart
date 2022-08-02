import 'dart:async';
import 'dart:convert';

import 'package:cupertino_http/cupertino_client.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _BookListState();
}

class _BookListState extends State<MyApp> {
  late Client client;
  late Future<Response> response;

  @override
  void initState() {
    super.initState();
    client = CupertinoClient.defaultSessionConfiguration();
    response = client.get(
        Uri.https('www.googleapis.com', '/books/v1/volumes', {'q': '{http}'}));
  }

  Widget _dataTable(Response response) {
    final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

    final items = decodedResponse['items'] as List<dynamic>;

    final rows = List<DataRow>.from(items.map((i) => DataRow(cells: <DataCell>[
          DataCell(Text(i['volumeInfo']['title'])),
          i['volumeInfo']['publishedDate'] == null
              ? DataCell.empty
              : DataCell(Text(i['volumeInfo']['publishedDate'])),
          DataCell(Text(i['volumeInfo']['description'])),
        ])));

    return DataTable(columns: const <DataColumn>[
      DataColumn(
        label: Text(
          'Title',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
      DataColumn(
        label: Text(
          'Published',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
      DataColumn(
        label: Text(
          'Description',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    ], rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Book Search'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                FutureBuilder<Response>(
                  future: response,
                  builder:
                      (BuildContext context, AsyncSnapshot<Response> value) {
                    if (value.hasData) {
                      return _dataTable(value.data!);
                    } else if (value.hasError) {
                      return Text(
                        value.error.toString(),
                        style: textStyle,
                        textAlign: TextAlign.center,
                      );
                    } else {
                      return const Text(
                        'Loading...',
                        style: textStyle,
                        textAlign: TextAlign.center,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
