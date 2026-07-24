/// Reads a required field of type [T] from [map], throwing a descriptive
/// [FormatException] if the field is missing (null) or not of type [T].
///
/// This is used by model `fromMap` factories to fail fast and clearly when
/// deserializing corrupted or partially-written stored maps, instead of
/// throwing an opaque [TypeError] from a bare cast.
T requireField<T>(Map<String, dynamic> map, String key, String className) {
  final value = map[key];
  if (value is! T) {
    final actualDescription = value == null ? 'null' : value.runtimeType.toString();
    throw FormatException(
      "$className.fromMap: required field '$key' is missing or has the wrong "
      "type (expected $T, got $actualDescription)",
    );
  }
  return value;
}
