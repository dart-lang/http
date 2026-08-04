// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';

void main() {
  final Client httpClient;
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
        userAgent: 'Package details Agent');
    httpClient = CronetClient.fromCronetEngine(engine, closeEngine: true);
  } else {
    httpClient = IOClient(HttpClient()..userAgent = 'Package details Agent');
  }

  runApp(Provider<Client>(
      create: (_) => httpClient,
      child: const PackageDetailsApp(),
      dispose: (_, client) => client.close()));
}

class PackageDetailsApp extends StatelessWidget {
  const PackageDetailsApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Package Details',
        home: PackageDetailsPage(),
      );
}

class PackageDetailsPage extends StatefulWidget {
  const PackageDetailsPage({super.key});

  @override
  State<PackageDetailsPage> createState() => _PackageDetailsPageState();
}

class _PackageDetailsPageState extends State<PackageDetailsPage> {
  String _output = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchPackageInfo();
  }

  void _fetchPackageInfo() async {
    final client = context.read<Client>();
    try {
      final response = await client.get(
        Uri.https('pub.dev', '/api/packages/cronet_http/score'),
      );
      if (response.statusCode == 200) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          _output = 'Information about package:cronet_http:\n'
              '- Likes: ${json['likeCount']}\n'
              '- 30-day downloads: ${json['downloadCount30Days']}';
        });
      } else {
        setState(() {
          _output = 'Request failed with status: ${response.statusCode}.';
        });
      }
    } catch (e) {
      setState(() {
        _output = 'Request failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _output,
              style: const TextStyle(fontSize: 18, fontFamily: 'monospace'),
            ),
          ),
        ),
      );
}
