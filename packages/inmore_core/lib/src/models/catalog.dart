import 'converters.dart';

/// A catalog entry is a vocabulary, not a constraint — a request item may have
/// no product behind it at all.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.category,
    this.defaultUnit,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        category: str(j['category']),
        defaultUnit: str(j['default_unit']),
        isActive: parseBool(j['is_active'], fallback: true),
        sortOrder: parseInt(j['sort_order'] ?? 0),
      );

  final String id;
  final String name;
  final String? category;
  final String? defaultUnit;
  final bool isActive;
  final int sortOrder;
}

class Partner {
  const Partner({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.services,
    this.notes,
    this.isActive = true,
  });

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: j['id'] as String,
        name: j['name'] as String,
        contactName: str(j['contact_name']),
        phone: str(j['phone']),
        email: str(j['email']),
        services: str(j['services']),
        notes: str(j['notes']),
        isActive: parseBool(j['is_active'], fallback: true),
      );

  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? services;
  final String? notes;
  final bool isActive;
}
