#!/bin/bash
set -e

password=pass:1234

if [ -d "test_certs" ]; then
  rm -rf test_certs
fi

mkdir test_certs

if [ -d "cert_tmp" ]; then
  rm -rf cert_tmp
fi

mkdir cert_tmp
cd cert_tmp

openssl req -passout $password \
            -new -newkey rsa:2048  -x509 \
            -subj /CN=localhost -keyout ca.key -out ca.crt

openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj /CN=localhost -config ../certificate_extensions.cnf


openssl x509 -passin $password \
        -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extensions v3_req -extfile ../certificate_extensions.cnf -out client.crt

openssl pkcs12 -passout $password \
        -export -in client.crt -inkey client.key -out client-cert.p12

mv client-cert.p12 ../test_certs
cd ..
rm -rf cert_tmp