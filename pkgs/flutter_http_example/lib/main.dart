// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

import 'http_client_factory.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart' as http_factory;
import 'package.dart';

void main() {
  runApp(Provider<Client>(
      create: (_) => http_factory.httpClient(),
      child: const PackageSearchApp(),
      dispose: (_, client) => client.close()));
}

class PackageSearchApp extends StatelessWidget {
  const PackageSearchApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pub.dev Package Search',
        home: HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String>? _allPackages;
  List<String>? _matchingNames;
  bool _loadingPackages = false;
  String? _lastQuery;
  late Client _client;

  @override
  void initState() {
    super.initState();
    _client = context.read<Client>();
    _loadPackageList();
  }

  Future<void> _loadPackageList() async {
    setState(() => _loadingPackages = true);
    try {
      final response = await _client.get(
        Uri.https('pub.dev', '/api/package-name-completion-data'),
      );
      if (response.statusCode == 200) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final packagesList = (json['packages'] as List<dynamic>).cast<String>()
          ..sort((a, b) => a.compareTo(b));
        setState(() {
          _allPackages = packagesList;
          _loadingPackages = false;
          _runSearch(_lastQuery ?? '');
        });
      }
    } catch (_) {
      setState(() => _loadingPackages = false);
    }
  }

  void _runSearch(String query) {
    _lastQuery = query;
    final allPackages = _allPackages;
    if (allPackages == null) return;

    if (query.isEmpty) {
      setState(() => _matchingNames = allPackages);
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _matchingNames = allPackages
          .where((name) => name.toLowerCase().contains(lowercaseQuery))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loadingPackages) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_matchingNames == null) {
      body = const Center(child: Text('Loading...'));
    } else {
      body = PackageTable(
        packageNames: _matchingNames!,
        client: _client,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pub.dev Package Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _runSearch,
              decoration: const InputDecoration(labelText: 'Search packages'),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class PackageTable extends StatelessWidget {
  final List<String> packageNames;
  final Client client;

  const PackageTable({
    required this.packageNames,
    required this.client,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Package Name',
                  ),
                ),
                Expanded(
                  child: Text(
                    'Likes',
                  ),
                ),
                Expanded(
                  child: Text(
                    '30-day Downloads',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: packageNames.length,
              itemBuilder: (context, index) {
                final name = packageNames[index];
                return PackageRow(
                  key: ValueKey(name),
                  name: name,
                  client: client,
                );
              },
            ),
          ),
        ],
      );
}

class PackageRow extends StatefulWidget {
  final String name;
  final Client client;

  const PackageRow({
    required this.name,
    required this.client,
    super.key,
  });

  @override
  State<PackageRow> createState() => _PackageRowState();
}

class _PackageRowState extends State<PackageRow> {
  late Future<Package> _scoreFuture;

  @override
  void initState() {
    super.initState();
    _scoreFuture = _fetchScore(widget.name, widget.client);
  }

  Future<Package> _fetchScore(String name, Client client) async {
    final response = await client.get(
      Uri.https('pub.dev', '/api/packages/$name/score'),
    );
    if (response.statusCode == 200) {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return Package.fromJson(name, json);
    } else {
      throw Exception('Failed to load score');
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(widget.name),
            ),
            Expanded(
              child: FutureBuilder<Package>(
                future: _scoreFuture,
                builder: (context, snapshot) {
                  final package = snapshot.data;
                  final likesText =
                      package != null ? package.likes.toString() : '...';
                  final downloadsText =
                      package != null ? package.downloads.toString() : '...';

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          likesText,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          downloadsText,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}
