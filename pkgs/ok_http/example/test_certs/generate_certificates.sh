#!/bin/bash
# Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Generates the test PKCS#12 certificates and private keys for package:ok_http.
# Compatible with macOS (LibreSSL / OpenSSL 3) and Linux (OpenSSL 1.1 / 3.x),
# and readable by Java/Android KeyStore across all supported Android API levels.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 1. Generate client key and certificate (test-combined.p12, password: 1234)
# Issuer must contain "Internet Widgits Pty Ltd" for certificate_test.dart.
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP_DIR/client.key" \
  -out "$TMP_DIR/client.crt" \
  -days 36500 \
  -subj "/C=AU/ST=Some-State/O=Internet Widgits Pty Ltd/CN=client" \
  2>/dev/null

openssl pkcs12 -export \
  -in "$TMP_DIR/client.crt" \
  -inkey "$TMP_DIR/client.key" \
  -out test-combined.p12 \
  -passout pass:1234 \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
  2>/dev/null

# 2. Generate server key and certificate (for server_chain.p12 and server_key.p12, password: dartdart)
# Includes SAN extension for localhost.
cat <<EOF > "$TMP_DIR/server_openssl.cnf"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
O = Dart
CN = localhost

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP_DIR/server.key" \
  -out "$TMP_DIR/server.crt" \
  -days 36500 \
  -config "$TMP_DIR/server_openssl.cnf" \
  2>/dev/null

# server_chain.p12 contains certificate only (no private key)
openssl pkcs12 -export \
  -in "$TMP_DIR/server.crt" \
  -nokeys \
  -out server_chain.p12 \
  -passout pass:dartdart \
  -certpbe PBE-SHA1-3DES -macalg sha1 \
  2>/dev/null

# server_key.p12 contains private key only (no certificates)
openssl pkcs12 -export \
  -inkey "$TMP_DIR/server.key" \
  -nocerts \
  -out server_key.p12 \
  -passout pass:dartdart \
  -keypbe PBE-SHA1-3DES -macalg sha1 \
  2>/dev/null

echo "Successfully generated test certificates in $SCRIPT_DIR:"
echo "  - test-combined.p12 (password: 1234)"
echo "  - server_chain.p12  (password: dartdart)"
echo "  - server_key.p12    (password: dartdart)"
