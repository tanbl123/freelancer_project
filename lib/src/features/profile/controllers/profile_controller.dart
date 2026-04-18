import '../../../shared/enums/user_role.dart';
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
      role: UserRole.freelancer,
      bio: 'Connect Firestore profile query here.',
    );
  }
}
