// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:typed_data/typed_buffers.dart';

import 'body.dart';
import 'multipart_file.dart';
import 'utils.dart';

/// A `multipart/form-data` request [Body]. Such a request has both string
/// fields, which function as normal form fields, and (potentially streamed)
/// binary files.
class MultipartBody implements Body {
  /// The contents of the message body.
  ///
  /// This will be `null` after [read] is called.
  Stream<List<int>> _stream;

  /// The length of the stream returned by [read].
  ///
  /// This is calculated from the fields and files passed into the body.
  final int contentLength;

  /// Multipart forms do not have an encoding.
  Encoding get encoding => null;

  /// Creates a [MultipartBody] from the given [fields] and [files].
  ///
  /// The [boundary] is used to
  factory MultipartBody(Map<String, String> fields,
      Iterable<MultipartFile> files, String boundary) {
    var controller = new StreamController<List<int>>(sync: true);
    var buffer = new Uint8Buffer();

    void writeAscii(String string) {
      buffer.addAll(string.codeUnits);
    }

    void writeUtf8(String string) {
      buffer.addAll(UTF8.encode(string));
    }

    void writeLine() {
      buffer.addAll([13, 10]); // \r\n
    }

    // Write the fields to the stream.
    fields.forEach((name, value) {
      writeAscii('--$boundary\r\n');
      writeUtf8(_headerForField(name, value));
      writeUtf8(value);
      writeLine();
    });

    controller.add(buffer);

    // Iterate over the files to get the length and compute the headers ahead
    // time so the length can be synchronously accessed.
    var fileList = files.toList();
    var fileHeaders = <List<int>>[];
    var fileContentsLength = 0;

    for (var file in fileList) {
      var header = <int>[];
      header.addAll('--$boundary\r\n'.codeUnits);
      header.addAll(UTF8.encode(_headerForFile(file)));
      fileContentsLength += header.length + file.length + 2;
      fileHeaders.add(header);
    }

    // Ending characters.
    var ending = '--$boundary--\r\n'.codeUnits;
    fileContentsLength += ending.length;

    // Write the files to the stream asynchronously.
    _writeFilesToStream(controller, files, fileHeaders, ending);

    return new MultipartBody._(
        controller.stream, buffer.length + fileContentsLength);
  }

  MultipartBody._(this._stream, this.contentLength);

  /// Returns a [Stream] representing the body.
  ///
  /// Can only be called once.
  Stream<List<int>> read() {
    if (_stream == null) {
      throw new StateError("The 'read' method can only be called once on a "
          "http.Request/http.Response object.");
    }
    var stream = _stream;
    _stream = null;
    return stream;
  }

  /// Writes the [files] to the [controller].
  static Future _writeFilesToStream(
      StreamController<List<int>> controller,
      List<MultipartFile> files,
      List<List<int>> fileHeaders,
      List<int> ending) async {
    for (var i = 0; i < files.length; ++i) {
      controller.add(fileHeaders[i]);
      await writeStreamToSink(files[i].read(), controller);
      controller.add([13, 10]);
    }

    controller.add(ending);
    controller.close();
  }

  /// Returns the header string for a field.
  static String _headerForField(String name, String value) {
    var header =
        'content-disposition: form-data; name="${_browserEncode(name)}"';
    if (!isPlainAscii(value)) {
      header = '$header\r\n'
          'content-type: text/plain; charset=utf-8\r\n'
          'content-transfer-encoding: binary';
    }
    return '$header\r\n\r\n';
  }

  /// Returns the header string for a file.
  ///
  /// The return value is guaranteed to contain only ASCII characters.
  static String _headerForFile(MultipartFile file) {
    var header = 'content-type: ${file.contentType}\r\n'
        'content-disposition: form-data; name="${_browserEncode(file.field)}"';

    if (file.filename != null) {
      header = '$header; filename="${_browserEncode(file.filename)}"';
    }
    return '$header\r\n\r\n';
  }

  static final _newlineRegExp = new RegExp(r"\r\n|\r|\n");

  /// Encode [value] in the same way browsers do.
  static String _browserEncode(String value) {
    // http://tools.ietf.org/html/rfc2388 mandates some complex encodings for
    // field names and file names, but in practice user agents seem not to
    // follow this at all. Instead, they URL-encode `\r`, `\n`, and `\r\n` as
    // `\r\n`; URL-encode `"`; and do nothing else (even for `%` or non-ASCII
    // characters). We follow their behavior.
    return value.replaceAll(_newlineRegExp, "%0D%0A").replaceAll('"', "%22");
  }
}
