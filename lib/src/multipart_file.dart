// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'content_type.dart';

/// A file to be uploaded as part of a `multipart/form-data` Request.
///
/// This doesn't need to correspond to a physical file.
class MultipartFile {
  /// The stream that will emit the file's contents.
  Stream<List<int>> _stream;

  /// The name of the form field for the file.
  final String field;

  /// The size of the file in bytes.
  ///
  /// This must be known in advance, even if this file is created from a
  /// [Stream].
  final int length;

  /// The basename of the file. May be null.
  final String filename;

  /// The content-type of the file.
  ///
  /// Defaults to `application/octet-stream`.
  final MediaType contentType;

  ///
  factory MultipartFile(String field, value,
      {String filename, MediaType contentType, Encoding encoding}) {
    List<int> bytes;
    var defaultMediaType;

    if (value is String) {
      encoding ??= encodingForMediaType(contentType) ?? UTF8;
      bytes = encoding.encode(value);
      defaultMediaType = new MediaType('text', 'plain');
    } else if (value is List<int>) {
      bytes = value;
      defaultMediaType = new MediaType('application', 'octet-stream');
    } else {
      throw new ArgumentError.value(
          value, 'value', 'value must be either a String or a List<int>');
    }

    contentType ??= _lookupMediaType(filename, bytes) ?? defaultMediaType;

    if (encoding != null) {
      contentType = contentType.change(parameters: {'charset': encoding.name});
    }

    return new MultipartFile.fromStream(
        field, new Stream<List<int>>.fromIterable([bytes]), bytes.length,
        filename: filename, contentType: contentType);
  }

  MultipartFile.fromStream(this.field, Stream<List<int>> stream, this.length,
      {String filename, MediaType contentType})
      : _stream = stream,
        filename = filename,
        contentType = contentType ??
            _lookupMediaType(filename) ??
            new MediaType('application', 'octet-stream');

  static Future<MultipartFile> loadStream(
      String field, Stream<List<int>> stream,
      {String filename, MediaType contentType}) async {
    var bytes = await collectBytes(stream);

    return new MultipartFile(field, bytes,
        filename: filename, contentType: contentType);
  }

  /// Returns a [Stream] representing the contents of the file.
  ///
  /// Can only be called once.
  Stream<List<int>> read() {
    if (_stream == null) {
      throw new StateError('The "read" method can only be called once on a '
          'http.MultipartFile object.');
    }
    var stream = _stream;
    _stream = null;
    return stream;
  }

  /// Looks up the [MediaType] from the [filename]'s extension or from
  /// magic numbers contained within a file header's [bytes].
  static MediaType _lookupMediaType(String filename, [List<int> bytes]) {
    if ((filename == null) && (bytes == null)) return null;

    // lookupMimeType expects filename to be non-null but its possible that
    // this can be called with bytes but no filename.
    var mimeType = lookupMimeType(filename ?? '', headerBytes: bytes);

    return mimeType != null ? new MediaType.parse(mimeType) : null;
  }
}
