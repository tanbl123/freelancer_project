import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../backend/shared/domain_types.dart';

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final DateTime? createdAt;

  factory AuthUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AuthUser(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: UserRole.values.byName(data['role'] as String? ?? UserRole.client.name),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
    };
  }
}
