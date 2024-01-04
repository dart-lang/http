import 'dart:convert';

/// This Fetch API interface allows you to perform various actions on HTTP
/// request and response headers. These actions include retrieving, setting,
/// adding to, and removing. A Headers object has an associated header list,
/// which is initially empty and consists of zero or more name and value pairs.
///  You can add to this using methods like append() (see Examples.) In all
/// methods of this interface, header names are matched by case-insensitive
/// byte sequence.
///
/// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers)
class Headers {
  final List<(String, String)> _storage;

  /// Internal constructor, to create a new instance of `Headers`.
  const Headers._(this._storage);

  /// The Headers() constructor creates a new Headers object.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/Headers)
  factory Headers([Object? init]) => Headers._((init,).toStorage());

  /// Appends a new value onto an existing header inside a Headers object, or
  /// adds the header if it does not already exist.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/append)
  void append(String name, String value) => _storage.add((name, value));

  /// Deletes a header from a Headers object.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/delete)
  void delete(String name) =>
      _storage.removeWhere((element) => element.$1.equals(name));

  /// Returns an iterator allowing to go through all key/value pairs contained
  /// in this object.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/entries)
  Iterable<(String, String)> entries() sync* {
    for (final (name, value) in _storage) {
      // https://fetch.spec.whatwg.org/#ref-for-forbidden-response-header-name%E2%91%A0
      if (name.equals('set-cookie')) continue;

      yield (name, value);
    }
  }

  /// Executes a provided function once for each key/value pair in this Headers object.
  ///
  /// [MDN Reference](https://developer.mozilla.org/en-US/docs/Web/API/Headers/forEach)
  void forEach(void Function(String value, String name, Headers parent) fn) =>
      entries().forEach((element) => fn(element.$2, element.$1, this));

  /// Returns a String sequence of all the values of a header within a Headers
  /// object with a given name.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/get)
  String? get(String name) => switch (_storage.valuesOf(name)) {
        Iterable<String> values when values.isNotEmpty => values.join(', '),
        _ => null,
      };

  /// Returns an array containing the values of all Set-Cookie headers
  /// associated with a response.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/getSetCookie)
  Iterable<String> getSetCookie() => _storage.valuesOf('Set-Cookie');

  /// Returns a boolean stating whether a Headers object contains a certain
  /// header.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/has)
  bool has(String name) => _storage.any((element) => element.$1.equals(name));

  /// Returns an iterator allowing you to go through all keys of the key/value
  /// pairs contained in this object.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/keys)
  Iterable<String> keys() => _storage.map((e) => e.$1).toSet();

  /// Sets a new value for an existing header inside a Headers object, or adds
  /// the header if it does not already exist.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/set)
  void set(String name, String value) => this
    ..delete(name)
    ..append(name, value);

  /// Returns an iterator allowing you to go through all values of the
  /// key/value pairs contained in this object.
  ///
  /// [MDN Reference](https://developer.mozilla.org/docs/Web/API/Headers/values)
  Iterable<String> values() => keys().map(get).whereType();
}

extension on String {
  bool equals(String other) => other.toLowerCase() == toLowerCase();
}

extension on Iterable<(String, String)> {
  Iterable<String> valuesOf(String name) =>
      where((element) => element.$1.equals(name)).map((e) => e.$2);
}

extension on (Object?,) {
  List<(String, String)> toStorage() => switch (this.$1) {
        Headers value => value.toStorage(),
        String value => value.toStorage(),
        Iterable<String> value => value.toStorage(),
        Iterable<(String, String)> value => value.toList(),
        Iterable<Iterable<String>> value => value.toStorage(),
        Map<String, String> value => value.toStorage(),
        Map<String, Iterable<String>> value => value.toStorage(),
        _ => [],
      };
}

extension on Map<String, Iterable<String>> {
  List<(String, String)> toStorage() => entries
      .map((e) => e.value.map((value) => (e.key, value)))
      .expand((e) => e)
      .toList();
}

extension on Map<String, String> {
  List<(String, String)> toStorage() =>
      entries.map((e) => (e.key, e.value)).toList();
}

extension on Iterable<Iterable<String>> {
  List<(String, String)> toStorage() {
    final storage = <(String, String)>[];
    for (final element in this) {
      switch (element) {
        case Iterable<String> value when value.length == 2:
          storage.add((value.first, value.last));
          break;
        case Iterable<String> value when value.length == 1:
          final pair = value.first.toHeadersPair();
          if (pair != null) storage.add(pair);
          break;
        case Iterable<String> value when value.length > 2:
          for (final element in value.skip(1)) {
            storage.add((value.first, element));
          }
          break;
      }
    }

    return storage;
  }
}

extension on Iterable<String> {
  List<(String, String)> toStorage() =>
      map((e) => e.toHeadersPair()).whereType<(String, String)>().toList();
}

extension on Headers {
  List<(String, String)> toStorage() => entries().toList();
}

extension on String {
  /// Converts a string to a list of headers.
  List<(String, String)> toStorage() =>
      const LineSplitter().convert(this).toStorage();

  /// Parses to a header pair.
  (String, String)? toHeadersPair() {
    final index = indexOf(':');
    if (index == -1) return null;

    return (substring(0, index), substring(index + 1).trim());
  }
}
