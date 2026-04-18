import '../enums/account_status.dart';
import '../enums/user_role.dart';
import '../../features/profile/models/profile_user.dart';

/// Centralised role + status access rules.
/// All business gate checks go here — never inline in widgets.
class AccessGuard {
  AccessGuard._();

  static bool canPostJob(ProfileUser? user) =>
      user != null &&
      user.accountStatus.canPost &&
      (user.role == UserRole.client || user.role == UserRole.freelancer);

  static bool canApplyToJob(ProfileUser? user) =>
      user != null &&
      user.accountStatus.canPost &&
      user.role == UserRole.freelancer;

  /// Active freelancers can create and manage service listings.
  static bool canCreateService(ProfileUser? user) =>
      user != null &&
      user.accountStatus == AccountStatus.active &&
      user.role == UserRole.freelancer;

  static bool canOrderService(ProfileUser? user) =>
      user != null &&
      user.accountStatus.canPost &&
      (user.role == UserRole.client || user.role == UserRole.freelancer);

  static bool canRequestFreelancerUpgrade(ProfileUser? user) =>
      user != null &&
      user.accountStatus == AccountStatus.active &&
      user.role == UserRole.client;

  static bool canSubmitAppeal(ProfileUser? user) =>
      user != null &&
      (user.accountStatus == AccountStatus.restricted ||
          user.accountStatus == AccountStatus.deactivated);

  static bool isAdmin(ProfileUser? user) =>
      user != null && user.role == UserRole.admin;

  static bool canAccessAdminDashboard(ProfileUser? user) => isAdmin(user);

  static bool needsEmailVerification(ProfileUser? user) =>
      user != null && user.accountStatus == AccountStatus.pendingVerification;
}
