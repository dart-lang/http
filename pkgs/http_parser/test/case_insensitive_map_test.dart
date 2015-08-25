// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

void main() {
  test("provides case-insensitive access to the map", () {
    var map = new CaseInsensitiveMap();
    map["fOo"] = "bAr";
    expect(map, containsPair("FoO", "bAr"));

    map["foo"] = "baz";
    expect(map, containsPair("FOO", "baz"));
  });

  test("stores the original key cases", () {
    var map = new CaseInsensitiveMap();
    map["fOo"] = "bAr";
    expect(map, equals({"fOo": "bAr"}));
  });

  test(".from() converts an existing map", () {
    var map = new CaseInsensitiveMap.from({"fOo": "bAr"});
    expect(map, containsPair("FoO", "bAr"));
    expect(map, equals({"fOo": "bAr"}));
  });
}
