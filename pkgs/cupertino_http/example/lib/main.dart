import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart';

import 'package:cupertino_http/cupertino_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late CupertinoClient client;
  late Future<Response> response;

  @override
  void initState() {
    super.initState();
    client = CupertinoClient.defaultSessionConfiguration();
    response = client.get(Uri.https('www.example.com', ''));
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Text(
                  'This calls a native function through FFI that is shipped as source in the package. '
                  'The native code is built as part of the Flutter Runner build.',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                Text(
                  'sum(1, 2) = $response',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                FutureBuilder<Response>(
                  future: response,
                  builder:
                      (BuildContext context, AsyncSnapshot<Response> value) {
                    final displayValue =
                        (value.hasData) ? value.data : 'loading';
                    return Text(
                      'await sumAsync(3, 4) = $displayValue',
                      style: textStyle,
                      textAlign: TextAlign.center,
                    );
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
