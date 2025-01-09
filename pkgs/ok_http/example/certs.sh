  559  openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=Oklahoma/L=Stillwater/O=My Company/OU=Engineering/CN=test.com" -keyout ca.key -out ca.crt
  560  openssl genrsa -out "test.key" 2048
  561  openssl req -new -key test.key -out test.csr -config openssl.cnf
  562  openssl x509 -req -days 3650 -in test.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extensions v3_req -extfile openssl.cnf -out test.crt
  563  cd ..
  564  rm -rf key/
  565  cd te
  566  ls
  567  cd integration_test/
  568  ls
  569  openssl pkcs12 -export -in test.crt -inkey test.key -out test-combined.p12
  570  openssl pkcs12 -export -in localhost.crt -inkey localhost.key -out test-combined.p12