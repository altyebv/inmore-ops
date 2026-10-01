/// A write the database refused.
///
/// There are two ways this happens and the difference matters:
///
/// * an **RLS policy** filters the row out *silently* — the statement affects
///   zero rows and Postgres raises nothing;
/// * a **trigger guard** raises `insufficient_privilege`.
///
/// So "no exception" is not success. Every mutating call in this layer uses
/// `.select()` and runs the result through [requireRow], which turns the
/// silent case into this exception. A repository that skipped that would show
/// a cheerful "Saved" when nothing was saved.
class PermissionDeniedException implements Exception {
  const PermissionDeniedException([this.what]);

  final String? what;

  @override
  String toString() => what == null
      ? 'You do not have permission to do that.'
      : 'You do not have permission to $what.';
}

/// Something that should exist does not — usually a stale id after someone
/// else cancelled or deleted the row.
class NotFoundException implements Exception {
  const NotFoundException(this.what);

  final String what;

  @override
  String toString() => '$what could not be found.';
}

/// NOTE ON `.order(...)`: postgrest-dart defaults `ascending` to **false**.
/// Every `.order()` in this layer passes it explicitly, because the failure is
/// silent — a reversed product list or a backwards Excel export looks like
/// data, not a bug.
///
/// Unwrap a single-row result from a write, treating "no rows" as a denial.
Map<String, dynamic> requireRow(List<dynamic> rows, String what) {
  if (rows.isEmpty) throw PermissionDeniedException(what);
  return Map<String, dynamic>.from(rows.first as Map);
}
