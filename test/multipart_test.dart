// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('empty', () {
    var request = new http.Request.multipart(dummyUrl);
    expect(request, bodyMatches('''
        --{{boundary}}--
        '''));
  });

  test('with fields and files', () {
    var fields = <String, String>{
      'field1': 'value1',
      'field2': 'value2',
    };
    var files = [
      new http.MultipartFile.fromString("file1", "contents1",
          filename: "filename1.txt"),
      new http.MultipartFile.fromString("file2", "contents2"),
    ];

    var request =
        new http.Request.multipart(dummyUrl, fields: fields, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-disposition: form-data; name="field1"

        value1
        --{{boundary}}
        content-disposition: form-data; name="field2"

        value2
        --{{boundary}}
        content-type: text/plain; charset=utf-8
        content-disposition: form-data; name="file1"; filename="filename1.txt"

        contents1
        --{{boundary}}
        content-type: text/plain; charset=utf-8
        content-disposition: form-data; name="file2"

        contents2
        --{{boundary}}--
        '''));
  });

  test('with a unicode field name', () {
    var fields = {'fïēld': 'value'};

    var request = new http.Request.multipart(dummyUrl, fields: fields);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-disposition: form-data; name="fïēld"

        value
        --{{boundary}}--
        '''));
  });

  test('with a field name with newlines', () {
    var fields = {'foo\nbar\rbaz\r\nbang': 'value'};
    var request = new http.Request.multipart(dummyUrl, fields: fields);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-disposition: form-data; name="foo%0D%0Abar%0D%0Abaz%0D%0Abang"

        value
        --{{boundary}}--
        '''));
  });

  test('with a field name with a quote', () {
    var fields = {'foo"bar': 'value'};
    var request = new http.Request.multipart(dummyUrl, fields: fields);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-disposition: form-data; name="foo%22bar"

        value
        --{{boundary}}--
        '''));
  });

  test('with a unicode field value', () {
    var fields = {'field': 'vⱥlūe'};
    var request = new http.Request.multipart(dummyUrl, fields: fields);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-disposition: form-data; name="field"
        content-type: text/plain; charset=utf-8
        content-transfer-encoding: binary

        vⱥlūe
        --{{boundary}}--
        '''));
  });

  test('with a unicode filename', () {
    var files = [
      new http.MultipartFile.fromString('file', 'contents',
          filename: 'fïlēname.txt')
    ];
    var request = new http.Request.multipart(dummyUrl, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-type: text/plain; charset=utf-8
        content-disposition: form-data; name="file"; filename="fïlēname.txt"

        contents
        --{{boundary}}--
        '''));
  });

  test('with a filename with newlines', () {
    var files = [
      new http.MultipartFile.fromString('file', 'contents',
          filename: 'foo\nbar\rbaz\r\nbang')
    ];
    var request = new http.Request.multipart(dummyUrl, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-type: text/plain; charset=utf-8
        content-disposition: form-data; name="file"; filename="foo%0D%0Abar%0D%0Abaz%0D%0Abang"

        contents
        --{{boundary}}--
        '''));
  });

  test('with a filename with a quote', () {
    var files = [
      new http.MultipartFile.fromString('file', 'contents', filename: 'foo"bar')
    ];
    var request = new http.Request.multipart(dummyUrl, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-type: text/plain; charset=utf-8
        content-disposition: form-data; name="file"; filename="foo%22bar"

        contents
        --{{boundary}}--
        '''));
  });

  test('with a string file with a content-type but no charset', () {
    var files = [
      new http.MultipartFile.fromString('file', '{"hello": "world"}',
          contentType: new MediaType('application', 'json'))
    ];
    var request = new http.Request.multipart(dummyUrl, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-type: application/json; charset=utf-8
        content-disposition: form-data; name="file"

        {"hello": "world"}
        --{{boundary}}--
        '''));
  });

  test('with a file with a iso-8859-1 body', () {
    // "Ã¥" encoded as ISO-8859-1 and then read as UTF-8 results in "å".
    var files = [
      new http.MultipartFile.fromString('file', 'non-ascii: "Ã¥"',
          contentType:
              new MediaType('text', 'plain', {'charset': 'iso-8859-1'}))
    ];
    var request = new http.Request.multipart(dummyUrl, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-type: text/plain; charset=iso-8859-1
        content-disposition: form-data; name="file"

        non-ascii: "å"
        --{{boundary}}--
        '''));
  });

  test('with a stream file', () {
    var controller = new StreamController(sync: true);
    var files = [new http.MultipartFile('file', controller.stream, 5)];
    var request = new http.Request.multipart(dummyUrl, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-type: application/octet-stream
        content-disposition: form-data; name="file"

        hello
        --{{boundary}}--
        '''));

    controller.add([104, 101, 108, 108, 111]);
    controller.close();
  });

  test('with an empty stream file', () {
    var controller = new StreamController(sync: true);
    var files = [new http.MultipartFile('file', controller.stream, 0)];
    var request = new http.Request.multipart(dummyUrl, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-type: application/octet-stream
        content-disposition: form-data; name="file"


        --{{boundary}}--
        '''));

    controller.close();
  });

  test('with a byte file', () {
    var files = [
      new http.MultipartFile.fromBytes('file', [104, 101, 108, 108, 111])
    ];
    var request = new http.Request.multipart(dummyUrl, files: files);

    expect(request, bodyMatches('''
        --{{boundary}}
        content-type: application/octet-stream
        content-disposition: form-data; name="file"

        hello
        --{{boundary}}--
        '''));
  });
}
