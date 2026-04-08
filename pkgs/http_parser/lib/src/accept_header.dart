// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:string_scanner/string_scanner.dart';
import 'media_type.dart';
import 'scan.dart';
import 'utils.dart';

/// Parses an HTTP Accept header.
///
/// Returns a list of [MediaType] objects sorted by preference.
/// Preference is determined by:
/// 1. Quality factor `q` (higher is better).
/// 2. Specificity (more specific is better).
/// 3. Number of parameters (more is better).
List<MediaType> parseAcceptHeader(String headerValue) {
  if (headerValue.isEmpty) return [];

  return wrapFormatException('Accept header', headerValue, () {
    final scanner = StringScanner(headerValue);
    final mediaTypes = parseList(scanner, () => parseFromScanner(scanner));
    scanner.expectDone();

    // Sort by preference
    mediaTypes.sort((a, b) {
      final qA = double.tryParse(a.parameters['q'] ?? '1.0') ?? 1.0;
      final qB = double.tryParse(b.parameters['q'] ?? '1.0') ?? 1.0;

      if (qA != qB) {
        return qB.compareTo(qA); // Higher q first
      }

      // Specificity
      // type/subtype > type/* > */*
      final specificityA = _getSpecificity(a);
      final specificityB = _getSpecificity(b);

      if (specificityA != specificityB) {
        return specificityB.compareTo(specificityA); // More specific first
      }

      // If still equal, number of parameters (excluding q)
      final paramsA = a.parameters.keys.where((k) => k != 'q').length;
      final paramsB = b.parameters.keys.where((k) => k != 'q').length;
      return paramsB.compareTo(paramsA); // More parameters first
    });

    return mediaTypes;
  });
}

int _getSpecificity(MediaType mediaType) {
  if (mediaType.type == '*') return 0;
  if (mediaType.subtype == '*') return 1;
  return 2;
}
