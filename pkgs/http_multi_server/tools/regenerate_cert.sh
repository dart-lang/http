#!/bin/bash

openssl genpkey -algorithm RSA -out localhost.key \
                -aes256 -pass pass:dartdart 2>/dev/null

openssl req -new -x509 -key localhost.key -days 36500 -out localhost.crt \
            -config tools/openssl.cfg -extensions v3_req -passin \
            pass:dartdart 2>/dev/null

KEY_CONTENT=$(cat localhost.key)
CERT_CONTENT=$(cat localhost.crt)

cat <<EOF > test/cert.dart
import 'dart:convert';

List<int> sslKey = utf8.encode(r'''
${KEY_CONTENT}
''');

List<int> sslCert = utf8.encode(r'''
${CERT_CONTENT}
''');
EOF

rm localhost.key localhost.crt
