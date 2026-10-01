import '../enums/employee_role.dart';
import 'converters.dart';

/// A member of staff. [id] is also the Supabase auth user id.
class Employee {
  const Employee({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String,
        role: EmployeeRole.fromWire(j['role'] as String),
        isActive: parseBool(j['is_active']),
        phone: str(j['phone']),
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
