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
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pub.dev Package Search',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF38BDF8),
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
            ),
            prefixIconColor: const Color(0xFF94A3B8),
            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
        home: const HomePage(),
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
        final json = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final packagesList = (json['packages'] as List<dynamic>)
            .cast<String>()
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
      body = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading package database...',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    } else if (_matchingNames == null) {
      body = const Center(
        child: Text(
          'Loading...',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    } else {
      body = PackageTable(
        packageNames: _matchingNames!,
        client: _client,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pub.dev Package Search',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            TextField(
              onChanged: _runSearch,
              decoration: const InputDecoration(
                labelText: 'Search packages',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: body),
          ],
        ),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: const Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Package Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Likes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '30-day Downloads',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF334155)),
            Expanded(
              child: ListView.builder(
                itemCount: packageNames.length,
                itemBuilder: (context, index) {
                  final name = packageNames[index];
                  final isEven = index.isEven;
                  return PackageRow(
                    key: ValueKey(name),
                    name: name,
                    client: client,
                    isEven: isEven,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PackageRow extends StatefulWidget {
  final String name;
  final Client client;
  final bool isEven;

  const PackageRow({
    required this.name,
    required this.client,
    required this.isEven,
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
      final json = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      return Package.fromJson(name, json);
    } else {
      throw Exception('Failed to load score');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rowBgColor =
        widget.isEven ? const Color(0xFF0F172A) : const Color(0xFF1E293B);

    return Container(
      color: rowBgColor,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              widget.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: FutureBuilder<Package>(
              future: _scoreFuture,
              builder: (context, snapshot) {
                final package = snapshot.data;
                final likesText =
                    package != null ? package.likes.toString() : '...';
                final downloadsText =
                    package != null ? package.downloads.toString() : '...';

                final isWaiting =
                    snapshot.connectionState == ConnectionState.waiting;

                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        likesText,
                        style: TextStyle(
                          color: isWaiting
                              ? const Color(0xFF64748B)
                              : const Color(0xFFE2E8F0),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        downloadsText,
                        style: TextStyle(
                          color: isWaiting
                              ? const Color(0xFF64748B)
                              : const Color(0xFFE2E8F0),
                        ),
                        textAlign: TextAlign.right,
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
}
