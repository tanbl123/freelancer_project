import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../services/supabase_service.dart';
import '../../../shared/enums/account_status.dart';
import '../../../shared/enums/appeal_status.dart';
import '../../../shared/enums/request_status.dart';
import '../../../shared/enums/user_role.dart';
import '../../../shared/guards/access_guard.dart';
import '../../profile/models/profile_user.dart';
import '../models/appeal.dart';
import '../models/freelancer_request.dart';
import '../repositories/appeal_repository.dart';
import '../repositories/freelancer_request_repository.dart';

/// Business logic layer for the User Module.
/// All enforcement of user rules lives here.
class UserService {
  final SupabaseService _db;
  final FreelancerRequestRepository _requestRepo;
  final AppealRepository _appealRepo;
  static const _uuid = Uuid();

  UserService(this._db, this._requestRepo, this._appealRepo);

  // ── Registration ─────────────────────────────────────────────────────────

  /// Creates a Supabase Auth user and initiates OTP email verification.
  /// New users always start as Client; the full profile is created after OTP.
  /// Returns null on success, or an error message string on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? photoUrl,
  }) async {
    try {
      // ── Pre-flight: block deactivated accounts ───────────────────────────
      // Check whether this email already exists in the profiles table with a
      // deactivated status.  We do this BEFORE calling signUp() so we never
      // create a new auth record for a banned email address.
      final existing =
          await _db.getUserByEmail(email.trim().toLowerCase());
      if (existing != null) {
        switch (existing.accountStatus) {
          case AccountStatus.active:
            return 'An account with this email already exists. '
                'Please sign in instead.';
          case AccountStatus.pendingVerification:
            // Account exists but email not yet verified — resend the OTP and
            // return null so the caller navigates to EmailVerificationScreen.
            await Supabase.instance.client.auth
                .resend(type: OtpType.signup, email: email.trim().toLowerCase());
            return null;
          case AccountStatus.deactivated:
            return 'This account has been deactivated and cannot be used to '
                'register.';
          case AccountStatus.restricted:
            return 'This account has been restricted. Please log in and submit '
                'an appeal from your profile page.';
        }
      }
      // ────────────────────────────────────────────────────────────────────

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (authResponse.user == null) {
        return 'Registration failed. Please try again.';
      }
      // NOTE: We do NOT call insertUser here.
      // When "Confirm email" is enabled, signUp() returns session = null
      // (user is not authenticated yet), so any RLS-protected INSERT would
      // fail with a 42501 error.  The profile row is created inside
      // AppState.verifySignupOtp() once the user has a confirmed session.
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred: $e';
    }
  }

  // ── Freelancer Upgrade Request ────────────────────────────────────────────

  /// Client submits a request to become a freelancer.
  /// Rules:
  ///   - User must be Active (not restricted, deactivated, or pendingVerification)
  ///   - User must currently be a Client
  ///   - Only one pending request allowed at a time
  Future<String?> submitFreelancerRequest(
    ProfileUser user,
    String message,
    String? portfolioUrl,
  ) async {
    if (!AccessGuard.canRequestFreelancerUpgrade(user)) {
      if (user.accountStatus != AccountStatus.active) {
        return 'Your account must be active to submit a request.';
      }
      return 'Only clients can request to become a freelancer.';
    }
    final existing = await _requestRepo.getPending(user.uid);
    if (existing != null) {
      return 'You already have a pending request. Please wait for admin review.';
    }
    if (message.trim().length < 20) {
      return 'Please provide at least 20 characters explaining your request.';
    }
    final req = FreelancerRequest(
      id: _uuid.v4(),
      requesterId: user.uid,
      status: RequestStatus.pending,
      requestMessage: message.trim(),
      portfolioUrl: portfolioUrl?.trim().isEmpty == true
          ? null
          : portfolioUrl?.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _requestRepo.create(req);
    return null;
  }

  // ── Admin: Approve Freelancer Request ─────────────────────────────────────

  /// Approves a freelancer request, upgrades the user's role.
  Future<String?> approveFreelancerRequest(
    String requestId,
    String adminId,
  ) async {
    try {
      final updated = await _requestRepo.updateStatus(
        requestId,
        RequestStatus.approved,
        reviewedBy: adminId,
      );
      // Upgrade the user's role in profiles
      await _db.updateUser(
        (await _db.getUserById(updated.requesterId))!.copyWith(
          role: UserRole.freelancer,
          accountStatus: AccountStatus.active,
        ),
      );
      return null;
    } catch (e) {
      return 'Failed to approve request: $e';
    }
  }

  // ── Admin: Reject Freelancer Request ──────────────────────────────────────

  Future<String?> rejectFreelancerRequest(
    String requestId,
    String adminId,
    String note,
  ) async {
    if (note.trim().isEmpty) return 'Please provide a rejection reason.';
    try {
      await _requestRepo.updateStatus(
        requestId,
        RequestStatus.rejected,
        adminNote: note.trim(),
        reviewedBy: adminId,
      );
      return null;
    } catch (e) {
      return 'Failed to reject request: $e';
    }
  }

  // ── Appeal ────────────────────────────────────────────────────────────────

  /// Restricted or deactivated user submits an appeal.
  /// Rules:
  ///   - Only restricted or deactivated users may appeal
  ///   - One open appeal at a time per user
  ///   - Reason must be at least 30 characters
  Future<String?> submitAppeal(
    ProfileUser user,
    String reason,
    List<String> evidenceUrls,
  ) async {
    if (!AccessGuard.canSubmitAppeal(user)) {
      return 'Only restricted or deactivated accounts may submit an appeal.';
    }
    final existing = await _appealRepo.getOpenForUser(user.uid);
    if (existing != null) {
      return 'You already have an open appeal. Please wait for admin review.';
    }
    if (reason.trim().length < 30) {
      return 'Please provide at least 30 characters for your appeal reason.';
    }
    final appeal = Appeal(
      id: _uuid.v4(),
      appellantId: user.uid,
      reason: reason.trim(),
      evidenceUrls: evidenceUrls,
      status: AppealStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _appealRepo.create(appeal);
    return null;
  }

  // ── Admin: Resolve Appeal ─────────────────────────────────────────────────

  /// Admin approves or rejects an appeal.
  /// On approval, account_status is restored to Active.
  Future<String?> resolveAppeal(
    String appealId,
    AppealStatus resolution,
    String adminId,
    String response,
    String appellantId,
  ) async {
    if (resolution == AppealStatus.open ||
        resolution == AppealStatus.underReview) {
      return 'Resolution must be approved or rejected.';
    }
    if (response.trim().isEmpty) return 'Please provide a response.';
    try {
      await _appealRepo.updateStatus(
        appealId,
        resolution,
        adminResponse: response.trim(),
        reviewedBy: adminId,
      );
      if (resolution == AppealStatus.approved) {
        await _db.updateAccountStatus(appellantId, AccountStatus.active);
      }
      return null;
    } catch (e) {
      return 'Failed to resolve appeal: $e';
    }
  }

  // ── Admin: Change Account Status ──────────────────────────────────────────

  /// Changes a user's [AccountStatus].
  ///
  /// Performs a **defense-in-depth** admin check: even though [AppState]
  /// already gates this call behind `isAdmin`, the service verifies the actor's
  /// role from the database so that direct service-layer invocations are also
  /// safe.
  Future<String?> setAccountStatus(
    String targetUserId,
    AccountStatus status,
    String adminId,
  ) async {
    // Verify the actor is genuinely an admin (defense-in-depth).
    final actor = await _db.getUserById(adminId);
    if (actor == null || !actor.role.isAdmin) return 'Access denied.';

    if (targetUserId == adminId) {
      return 'Admins cannot change their own account status.';
    }
    try {
      await _db.updateAccountStatus(targetUserId, status);
      return null;
    } catch (e) {
      return 'Failed to update account status: $e';
    }
  }

  // ── Google Sign-In helper ─────────────────────────────────────────────────

  /// Creates a profile row if this is the user's first Google sign-in.
  /// Called from the auth state listener after OAuth completes.
  Future<ProfileUser> ensureGoogleProfile(User authUser) async {
    var profile = await _db.getUserById(authUser.id);
    if (profile == null) {
      profile = ProfileUser(
        uid: authUser.id,
        displayName: authUser.userMetadata?['full_name'] as String? ??
            authUser.email?.split('@').first ??
            'User',
        email: authUser.email ?? '',
        phone: '',
        role: UserRole.client,
        // Google verifies email, so set active directly
        accountStatus: AccountStatus.active,
        photoUrl: authUser.userMetadata?['avatar_url'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _db.insertUser(profile);
    }
    return profile;
  }
}
