enum UserMode { client, freelancer }

class AppUser {
  final String name;
  final String email;
  final bool isFreelancerEnabled;
  final UserMode currentMode;

  const AppUser({
    required this.name,
    required this.email,
    required this.isFreelancerEnabled,
    required this.currentMode,
  });

  AppUser copyWith({
    String? name,
    String? email,
    bool? isFreelancerEnabled,
    UserMode? currentMode,
  }) {
    return AppUser(
      name: name ?? this.name,
      email: email ?? this.email,
      isFreelancerEnabled: isFreelancerEnabled ?? this.isFreelancerEnabled,
      currentMode: currentMode ?? this.currentMode,
    );
  }
}
