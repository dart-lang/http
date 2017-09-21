// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import 'utils.dart';

/// A file to be uploaded as part of a [MultipartRequest]. This doesn't need to
/// correspond to a physical file.
class MultipartFile {
  /// The stream that will emit the file's contents.
  Stream<List<int>> _stream;

  /// The name of the form field for the file.
  final String field;

  /// The size of the file in bytes. This must be known in advance, even if this
  /// file is created from a [Stream].
  final int length;

  /// The basename of the file. May be null.
  final String filename;

  /// The content-type of the file. Defaults to `application/octet-stream`.
  final MediaType contentType;

  /// Creates a new [MultipartFile] from a chunked [Stream] of bytes. The length
  /// of the file in bytes must be known in advance. If it's not, read the data
  /// from the stream and use [MultipartFile.fromBytes] instead.
  ///
  /// [contentType] currently defaults to `application/octet-stream`, but in the
  /// future may be inferred from [filename].
  MultipartFile(this.field, Stream<List<int>> stream, this.length,
      {this.filename, MediaType contentType})
      : this._stream = stream,
        this.contentType = contentType != null
            ? contentType
            : new MediaType("application", "octet-stream");

  /// Creates a new [MultipartFile] from a byte array.
  ///
  /// [contentType] currently defaults to `application/octet-stream`, but in the
  /// future may be inferred from [filename].
  factory MultipartFile.fromBytes(String field, List<int> value,
      {String filename, MediaType contentType}) {
    var stream = new Stream.fromIterable([DelegatingList.typed(value)]);
    return new MultipartFile(field, stream, value.length,
        filename: filename, contentType: contentType);
  }

  /// Creates a new [MultipartFile] from a string.
  ///
  /// The encoding to use when translating [value] into bytes is taken from
  /// [contentType] if it has a charset set. Otherwise, it defaults to UTF-8.
  /// [contentType] currently defaults to `text/plain; charset=utf-8`, but in
  /// the future may be inferred from [filename].
  factory MultipartFile.fromString(String field, String value,
      {String filename, MediaType contentType}) {
    contentType =
        contentType == null ? new MediaType("text", "plain") : contentType;
    var encoding = encodingForCharset(contentType.parameters['charset'], UTF8);
    contentType = contentType.change(parameters: {'charset': encoding.name});

    return new MultipartFile.fromBytes(field, encoding.encode(value),
        filename: filename, contentType: contentType);
  }

  // TODO(nweiz): Infer the content-type from the filename.
  /// Creates a new [MultipartFile] from a path to a file on disk.
  ///
  /// [filename] defaults to the basename of [filePath]. [contentType] currently
  /// defaults to `application/octet-stream`, but in the future may be inferred
  /// from [filename].
  ///
  /// Throws an [UnsupportedError] if `dart:io` isn't supported in this
  /// environment.
  static Future<MultipartFile> fromPath(String field, String filePath,
      {String filename, MediaType contentType}) async {
    if (filename == null) filename = path.basename(filePath);
    var file = new File(filePath);
    var length = await file.length();
    var stream = DelegatingStream.typed(file.openRead());
    return new MultipartFile(field, stream, length,
        filename: filename, contentType: contentType);
  }

  /// Returns a [Stream] representing the file.
  ///
  /// Can only be called once.
  Stream<List<int>> read() {
    if (_stream == null) {
      throw new StateError("The 'read' method can only be called once on a "
          "http.MultipartFile object.");
    }
    var stream = _stream;
    _stream = null;
    return stream;
  }
}
