import 'converters.dart';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.company,
    this.email,
    this.notes,
    this.phoneNormalized,
    this.isArchived = false,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: str(j['phone']),
        company: str(j['company']),
        email: str(j['email']),
        notes: str(j['notes']),
        phoneNormalized: str(j['phone_normalized']),
        isArchived: parseBool(j['is_archived']),
        createdAt: parseTimestampOrNull(j['created_at']),
      );

  final String id;
  final String name;
  final String? phone;
  final String? company;
  final String? email;
  final String? notes;

  /// Digits only, +974 stripped. Matching happens on this, never on [phone].
  final String? phoneNormalized;
  final bool isArchived;
  final DateTime? createdAt;

  /// "Khalid Al-Mansour · Mansour Trading"
  String get displayLine =>
      (company == null || company!.isEmpty) ? name : '$name · $company';
}
