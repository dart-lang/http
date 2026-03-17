// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(
    args,
    (input, output) async =>
        CBuilder.library(
          name: 'cupertino_http',
          assetName: 'src/native_cupertino_bindings.dart',
          sources: ['src/native_cupertino_bindings.m'],
          language: Language.objectiveC,
          flags: ['-fobjc-arc'],
        ).run(
          input: input,
          output: output,
          logger: Logger('')
            ..level = Level.ALL
            ..onRecord.listen((record) {
              print('${record.level.name}: ${record.time}: ${record.message}');
            }),
        ),
  );
}
