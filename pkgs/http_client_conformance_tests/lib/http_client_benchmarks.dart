import 'dart:async';

import 'package:http/http.dart';
import 'dart:math';

Future<double> runMany(Future<double> Function() fn) async {
  var l = double.maxFinite;

  for (var i = 0; i < 100; ++i) {
    l = min(l, await fn());
  }
  return l;
}

Future<double> testN(Client Function() clientFn, int i) async {
  final client = clientFn();

  final stopwatch = Stopwatch()..start();
  for (var j = 1; j <= i; ++j) {
    final url = Uri.http(
        'localhost:8080', '/${Random().nextInt(10000)}'); // 10.0.2.2:8080
    await client.read(url);
  }
  stopwatch.stop();
  client.close();
  return stopwatch.elapsed.inMicroseconds * 1e-6;
}

Future<double> benchmark(Client Function() clientFn) async {
  final client = clientFn();
  final stopwatch = Stopwatch()..start();

  final url = Uri.http(
      'localhost:8080', '/${Random().nextInt(10000)}'); // 10.0.2.2:8080
  await client.read(url);
  stopwatch.stop();
  client.close();
  return stopwatch.elapsed.inMicroseconds * 1e-6;
}

Future<Map<String, double>> foo(Client Function() clientFn) async {
  final results = <double>[];
  final stopwatch = Stopwatch()..start();
  await benchmark(clientFn);
  while (stopwatch.elapsed < const Duration(seconds: 5)) {
    results.add(await benchmark(clientFn));
  }
  return {
    'min': results.fold<double>(double.maxFinite, min),
    'median': results.fold<double>(0, (x, y) => x + y) / results.length
  };
}

Stream<Map<String, double>> benchmarkAll(Client Function() clientFn) {
  final sc = StreamController<Map<String, double>>();

  foo(clientFn).then((x) {
    sc
      ..add(x)
      ..close();
  });

//  sc.close();
  return sc.stream;
/*
  for (var i = 1; i <= 10; ++i) {
    print('$i => ${await runMany(() => testN(clientFn, i)) / i}');
  }
*/
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
