// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
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
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Package Details',
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: const PackageDetailsPage(),
      );
}

class PackageDetailsPage extends StatefulWidget {
  const PackageDetailsPage({super.key});

  @override
  State<PackageDetailsPage> createState() => _PackageDetailsPageState();
}

class _PackageDetailsPageState extends State<PackageDetailsPage> {
  late Future<PackageInfo> _packageInfoFuture;
  late Client _client;

  @override
  void initState() {
    super.initState();
    _client = context.read<Client>();
    _packageInfoFuture = _fetchPackageInfo();
  }

  Future<PackageInfo> _fetchPackageInfo() async {
    const packageName = 'cronet_http';
    final results = await Future.wait([
      _client.get(Uri.https('pub.dev', '/api/packages/$packageName/score')),
      _client.get(Uri.https('pub.dev', '/api/packages/$packageName/publisher')),
    ]);

    final scoreResponse = results[0];
    final publisherResponse = results[1];

    if (scoreResponse.statusCode == 200 &&
        publisherResponse.statusCode == 200) {
      final scoreJson = jsonDecode(utf8.decode(scoreResponse.bodyBytes))
          as Map<String, dynamic>;
      final publisherJson = jsonDecode(utf8.decode(publisherResponse.bodyBytes))
          as Map<String, dynamic>;
      return PackageInfo(
        name: packageName,
        likes: scoreJson['likeCount'] as int? ?? 0,
        downloads: scoreJson['downloadCount30Days'] as int? ?? 0,
        publisherId: publisherJson['publisherId'] as String?,
      );
    } else {
      throw Exception('Failed to load package info');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Package Details'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                final info = snapshot.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (info.publisherId != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image(
                                  image: HttpImageProvider(
                                    Uri.https(
                                        'www.google.com', '/s2/favicons', {
                                      'sz': '64',
                                      'domain': info.publisherId!,
                                    }),
                                    client: _client,
                                  ),
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.public, size: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                info.publisherId!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.thumb_up_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text('${info.likes} Likes'),
                            const SizedBox(width: 24),
                            const Icon(Icons.download_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text('${info.downloads} Downloads'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
}

class PackageInfo {
  final String name;
  final int likes;
  final int downloads;
  final String? publisherId;

  PackageInfo({
    required this.name,
    required this.likes,
    required this.downloads,
    required this.publisherId,
  });
}
