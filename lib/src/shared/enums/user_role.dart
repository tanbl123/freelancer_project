enum UserRole {
  admin,
  client,
  freelancer;

  static UserRole fromString(String v) => UserRole.values.firstWhere(
        (e) => e.name == v,
        orElse: () => UserRole.client,
      );

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.client:
        return 'Client';
      case UserRole.freelancer:
        return 'Freelancer';
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isFreelancer => this == UserRole.freelancer;
  bool get isClient => this == UserRole.client;
}
