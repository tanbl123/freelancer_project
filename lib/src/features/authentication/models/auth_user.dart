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
  final String role; // 'client' | 'freelancer'
  final DateTime? createdAt;
}
