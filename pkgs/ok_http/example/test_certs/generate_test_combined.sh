#!/bin/bash
# Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Generates `test-combined.p12`: a PKCS #12 archive, with password "1234",
# containing a self-signed certificate and its private key.
#
# The archive is protected using legacy algorithms (a SHA-1 MAC and 3DES
# encryption) because the PKCS12 `KeyStore` in older versions of Android
# (e.g. API level 24) cannot read archives protected using the OpenSSL 3
# defaults (a SHA-256 MAC and PBES2/AES-256 encryption).

set -euo pipefail

cd "$(dirname "$0")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# `certificate_test.dart` checks that the certificate issuer contains
# "Internet Widgits Pty Ltd".
openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
  -days 36500 \
  -subj '/C=US/ST=CA/O=Internet Widgits Pty Ltd' \
  -keyout "$tmp_dir/key.pem" \
  -out "$tmp_dir/cert.pem"

openssl pkcs12 -export \
  -inkey "$tmp_dir/key.pem" \
  -in "$tmp_dir/cert.pem" \
  -keypbe PBE-SHA1-3DES \
  -certpbe PBE-SHA1-3DES \
  -macalg sha1 \
  -passout pass:1234 \
  -out test-combined.p12
