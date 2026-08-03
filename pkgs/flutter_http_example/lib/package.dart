// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class Package {
  final String name;
  final int likes;
  final int downloads;
  final String? publisherId;

  Package({
    required this.name,
    required this.likes,
    required this.downloads,
    required this.publisherId,
  });

  factory Package.fromJson(
    String name,
    Map<String, dynamic> json, {
    required String? publisherId,
  }) =>
      Package(
        name: name,
        likes: json['likeCount'] as int? ?? 0,
        downloads: json['downloadCount30Days'] as int? ?? 0,
        publisherId: publisherId,
      );
}
