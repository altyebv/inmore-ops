/// JSON helpers shared by the hand-written models.
///
/// Models are plain classes rather than generated ones — see the note in
/// pubspec.yaml. These functions carry the awkward cases so each model stays
/// a readable list of fields.
library;

/// PostgREST sends `numeric` as a JSON number, but a sufficiently large or
/// precise value arrives as a string. Accept both rather than crashing on a
/// five-digit quotation.
double parseNum(Object? v) => parseNumOrNull(v) ?? 0;

double? parseNumOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  throw ArgumentError('Not a number: $v (${v.runtimeType})');
}

int parseInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.parse(v);
  throw ArgumentError('Not an integer: $v');
}

int? parseIntOrNull(Object? v) => v == null ? null : parseInt(v);

bool parseBool(Object? v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is String) return v == 'true' || v == 't';
  return fallback;
}

/// A `date` column is 'YYYY-MM-DD' with no zone. Parsed as-is: treating it as
/// UTC and rendering locally would shift it a day in Qatar.
DateTime? parseDateOrNull(Object? v) =>
    v == null ? null : DateTime.parse(v as String);

/// `timestamptz` arrives as UTC. Converted once, here, so no screen has to
/// remember to.
DateTime parseTimestamp(Object? v) => DateTime.parse(v as String).toLocal();

DateTime? parseTimestampOrNull(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

String? dateToWire(DateTime? v) => v?.toIso8601String().split('T').first;

/// Trim, and treat an empty string as absent — the database prefers NULL to
/// '' and so do the screens.
String? str(Object? v) {
  if (v == null) return null;
  final s = (v as String).trim();
  return s.isEmpty ? null : s;
}

Map<String, dynamic> asMap(Object? v) =>
    v == null ? <String, dynamic>{} : Map<String, dynamic>.from(v as Map);
