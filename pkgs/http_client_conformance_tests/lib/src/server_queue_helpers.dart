import 'package:async/async.dart';

extension StreamQueueOfNullableObjectExtension on StreamQueue<Object?> {
  Future<int> get nextAsInt async => ((await next) as num).toInt();
}
