import 'package:postgres/postgres.dart';

/// Decodes a PostgreSQL column value to a [String].
///
/// Custom PostgreSQL enum types and UUIDs are returned as [UndecodedBytes]
/// by the `postgres` v3 package. This helper safely decodes them.
String decodeColumn(dynamic value) {
  if (value is UndecodedBytes) return value.asString;
  return value as String;
}
