# Certificates

The certificates and private keys used for `package:ok_http` TLS testing.

## Regenerating Certificates

To regenerate the certificates, run `generate_certificates.sh` on macOS or Linux:

```bash
cd pkgs/ok_http/example/test_certs
./generate_certificates.sh
```

This script requires `openssl` to be installed and generates:
- `test-combined.p12` (password: `1234`): Combined client private key and certificate.
- `server_chain.p12` (password: `dartdart`): Server certificate without private key.
- `server_key.p12` (password: `dartdart`): Server private key without certificate.

