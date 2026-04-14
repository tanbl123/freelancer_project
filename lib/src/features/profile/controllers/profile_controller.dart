import '../models/profile_user.dart';

class ProfileController {
  const ProfileController();

  Future<ProfileUser> getProfilePreview() async {
    return const ProfileUser(
      uid: 'preview-user',
      displayName: 'Preview User',
      email: '',
      passwordHash: '',
      phone: '',
      role: 'freelancer',
      bio: 'Connect Firestore profile query here.',
    );
  }
}
