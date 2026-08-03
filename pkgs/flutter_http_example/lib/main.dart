// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http_image_provider/http_image_provider.dart';
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
      body = PackageList(
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

class PackageList extends StatelessWidget {
  final List<String> packageNames;
  final Client client;

  const PackageList({
    required this.packageNames,
    required this.client,
    super.key,
  });

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: packageNames.length,
        itemBuilder: (context, index) {
          final name = packageNames[index];
          return PackageCard(
            key: ValueKey(name),
            name: name,
            client: client,
          );
        },
      );
}

class PackageCard extends StatefulWidget {
  final String name;
  final Client client;

  const PackageCard({
    required this.name,
    required this.client,
    super.key,
  });

  @override
  State<PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<PackageCard> {
  late Future<Package> _packageFuture;

  @override
  void initState() {
    super.initState();
    _packageFuture = _fetchPackageInfo(widget.name, widget.client);
  }

  Future<Package> _fetchPackageInfo(String name, Client client) async {
    final results = await Future.wait([
      client.get(Uri.https('pub.dev', '/api/packages/$name/score')),
      client.get(Uri.https('pub.dev', '/api/packages/$name/publisher')),
    ]);

    final scoreResponse = results[0];
    final publisherResponse = results[1];

    if (scoreResponse.statusCode == 200 &&
        publisherResponse.statusCode == 200) {
      final scoreJson = jsonDecode(utf8.decode(scoreResponse.bodyBytes))
          as Map<String, dynamic>;
      final publisherJson = jsonDecode(utf8.decode(publisherResponse.bodyBytes))
          as Map<String, dynamic>;
      final publisherId = publisherJson['publisherId'] as String?;
      return Package.fromJson(name, scoreJson, publisherId: publisherId);
    } else {
      throw Exception('Failed to load package info');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Package>(
          future: _packageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                    color: Color(0xFF38BDF8),
                    backgroundColor: Color(0xFF1E293B),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return Text(
                'Error loading info for ${widget.name}',
                style: const TextStyle(color: Colors.redAccent),
              );
            }

            final package = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          if (package.publisherId != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image(
                                    image: HttpImageProvider(
                                      Uri.parse(
                                          'https://www.google.com/s2/favicons?sz=64&domain=${package.publisherId}'),
                                      client: widget.client,
                                    ),
                                    width: 16,
                                    height: 16,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      Icons.public,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  package.publisherId!,
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.thumb_up_outlined,
                        size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      '${package.likes} Likes',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                    const SizedBox(width: 24),
                    const Icon(Icons.download_outlined,
                        size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      '${package.downloads} Downloads',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
