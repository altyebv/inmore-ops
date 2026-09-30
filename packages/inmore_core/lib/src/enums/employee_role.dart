/// Mirrors the PostgreSQL `employee_role` enum. The wire names must match the
/// database exactly — they are what PostgREST sends and accepts.
enum EmployeeRole {
  owner('OWNER', 'Owner'),
  supervisor('SUPERVISOR', 'Supervisor'),
  designer('DESIGNER', 'Designer'),
  production('PRODUCTION', 'Production');

  const EmployeeRole(this.wire, this.label);

  final String wire;
  final String label;

  static EmployeeRole fromWire(String value) => EmployeeRole.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => throw ArgumentError('Unknown employee_role: $value'),
      );

  /// The money boundary, mirrored client-side for UI purposes only.
  ///
  /// This decides what to *draw*. It is not enforcement — the real boundary is
  /// RLS on `quotations`, `quotation_lines`, `payments` and `task_costs`. A
  /// designer who got past this check would still receive zero rows.
  bool get canSeeMoney => this == owner || this == supervisor;

  bool get canManageRequests => this == owner || this == supervisor;
}
