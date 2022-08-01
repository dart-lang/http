import 'package:http/http.dart';
import 'dart:math';

Future<double> runMany(Future<double> Function() fn) async {
  var l = double.maxFinite;

  for (var i = 0; i < 1000; ++i) {
    l = min(l, await fn());
  }
  return l;
}

Future<double> testN(Client Function() clientFn, int i) async {
  final client = clientFn();

  final stopwatch = Stopwatch()..start();
  for (var j = 1; j <= i; ++j) {
    final url = Uri.http('10.0.2.2:8080', '/${Random().nextInt(10000)}');
    await client.read(url);
  }
  stopwatch.stop();
  client.close();
  return stopwatch.elapsed.inMicroseconds * 1e-6;
}

void benchmarkAll(Client Function() clientFn) async {
  for (var i = 1; i <= 10; ++i) {
    print('$i => ${await runMany(() => testN(clientFn, i)) / i}');
  }
  /*
  final url = Uri.http('localhost:8080', '');
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < 10; ++i) {
    await client.get(url);
  }
  stopwatch.stop();
  print(stopwatch.elapsed);
  */
}
