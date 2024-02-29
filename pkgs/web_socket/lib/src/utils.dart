import 'dart:convert';

void checkCode(int? code) {
  if (code != null) {
    RangeError.checkValueInInterval(code, 3000, 4999, 'code');
  }
}

void checkReason(String? reason) {
  if (reason != null && utf8.encode(reason).length > 123) {
    throw ArgumentError.value(reason, 'reason',
        'reason must be <= 123 bytes long when encoded as UTF-8');
  }
}
