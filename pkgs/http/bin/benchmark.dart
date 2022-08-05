import 'package:http/io_client.dart';
import 'package:http_client_conformance_tests/http_client_benchmarks.dart';

void main() {
  benchmarkAll(() => IOClient()).listen(print);
}
