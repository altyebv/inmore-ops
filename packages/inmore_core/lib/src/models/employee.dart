import '../enums/employee_role.dart';

/// A member of staff. `id` is also the Supabase auth user id.
class Employee {
  const Employee({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        role: EmployeeRole.fromWire(json['role'] as String),
        isActive: json['is_active'] as bool,
        phone: json['phone'] as String?,
      );

  final String id;
  final String fullName;
  final String email;
  final EmployeeRole role;
  final bool isActive;
  final String? phone;

  /// First name, for greetings. Falls back to the whole name.
  String get shortName => fullName.split(' ').first;
}
