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

# -subj "/C=US/ST=Oklahoma/L=Stillwater/O=My Company/OU=Engineering/CN=test.com"
#  559  openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=Oklahoma/L=Stillwater/O=My Company/OU=Engineering/CN=test.com" -keyout ca.key -out ca.crt
#  560  openssl genrsa -out "test.key" 2048
#  561  openssl req -new -key test.key -out test.csr -config openssl.cnf
#  562  openssl x509 -req -days 3650 -in test.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extensions v3_req -extfile openssl.cnf -out test.crt

openssl req -passout $password \
            -new -newkey rsa:2048  -days 3650 -nodes -x509 \
            -keyout ca.key -out ca.crt \
            -subj "/C=US/ST=CA/O=Internet Widgits Pty Ltd" 

openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr \
            -config ../certificate_extensions.cnf

 # -subj  "/C=US/ST=CA/O=Internet Widgits Pty Ltd" # -config ../certificate_extensions.cnf


openssl x509 -passin $password \
        -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extensions v3_req  -out client.crt -extfile ../certificate_extensions.cnf \

openssl pkcs12 -passout $password \
        -export -in client.crt -inkey client.key -out client-cert.p12

mv client-cert.p12 ../test_certs
cd ..
rm -rf cert_tmp