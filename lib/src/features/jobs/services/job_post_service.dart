import '../../../shared/enums/account_status.dart';
import '../../../shared/enums/job_status.dart';
import '../../../shared/guards/access_guard.dart';
import '../../profile/models/profile_user.dart';
import '../models/job_post.dart';
import '../repositories/job_post_repository.dart';

/// Business-logic layer for the Job Posting Module.
/// Enforces all rules before delegating persistence to [JobPostRepository].
class JobPostService {
  const JobPostService(this._repo);

  final JobPostRepository _repo;

  // ── Create ────────────────────────────────────────────────────────────────

  /// Returns null on success, error message on failure.
  Future<String?> createPost(ProfileUser actor, JobPost post) async {
    if (!AccessGuard.canPostJob(actor)) {
      return actor.accountStatus != AccountStatus.active
          ? 'Your account must be active to post a job.'
          : 'Only clients and freelancers can post jobs.';
    }
    final err = validatePost(post);
    if (err != null) return err;

    try {
      await _repo.create(post);
      return null;
    } catch (e) {
      return 'Failed to create post: $e';
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<String?> updatePost(ProfileUser actor, JobPost post) async {
    if (actor.uid != post.clientId && !AccessGuard.isAdmin(actor)) {
      return 'You can only edit your own job posts.';
    }
    if (post.status != JobStatus.open) {
      return 'Only open job posts can be edited.';
    }
    final err = validatePost(post);
    if (err != null) return err;

    try {
      await _repo.update(post);
      return null;
    } catch (e) {
      return 'Failed to update post: $e';
    }
  }

  // ── Status transitions ────────────────────────────────────────────────────

  Future<String?> closePost(ProfileUser actor, String postId,
      String ownerId) async {
    if (actor.uid != ownerId && !AccessGuard.isAdmin(actor)) {
      return 'You can only close your own job posts.';
    }
    try {
      await _repo.updateStatus(postId, JobStatus.closed);
      return null;
    } catch (e) {
      return 'Failed to close post: $e';
    }
  }

  Future<String?> cancelPost(ProfileUser actor, String postId,
      String ownerId) async {
    if (actor.uid != ownerId && !AccessGuard.isAdmin(actor)) {
      return 'You can only cancel your own job posts.';
    }
    try {
      await _repo.updateStatus(postId, JobStatus.cancelled);
      return null;
    } catch (e) {
      return 'Failed to cancel post: $e';
    }
  }

  Future<String?> reopenPost(ProfileUser actor, String postId,
      String ownerId) async {
    if (actor.uid != ownerId && !AccessGuard.isAdmin(actor)) {
      return 'You can only reopen your own job posts.';
    }
    try {
      await _repo.updateStatus(postId, JobStatus.open);
      return null;
    } catch (e) {
      return 'Failed to reopen post: $e';
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Soft-deletes a post by setting its status to [JobStatus.deleted].
  /// The row is preserved in Supabase for audit / referential integrity.
  Future<String?> deletePost(ProfileUser actor, String postId,
      String ownerId) async {
    if (actor.uid != ownerId && !AccessGuard.isAdmin(actor)) {
      return 'You can only delete your own job posts.';
    }
    try {
      await _repo.updateStatus(postId, JobStatus.deleted);
      return null;
    } catch (e) {
      return 'Failed to delete post: $e';
    }
  }

  // ── View tracking ─────────────────────────────────────────────────────────

  /// Fire-and-forget — increments view_count on Supabase, no UI feedback.
  Future<void> recordView(String postId) async {
    try {
      await _repo.incrementViewCount(postId);
    } catch (_) {
      // Non-critical; fail silently.
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Returns an error string if validation fails, null if valid.
  static String? validatePost(JobPost post) {
    final titleErr = validateTitle(post.title);
    if (titleErr != null) return titleErr;

    final descErr = validateDescription(post.description);
    if (descErr != null) return descErr;

    final budgetErr = validateBudget(post.budgetMin, post.budgetMax);
    if (budgetErr != null) return budgetErr;

    final deadlineErr = validateDeadline(post.deadline);
    if (deadlineErr != null) return deadlineErr;

    return null;
  }

  static String? validateTitle(String? v) {
    if (v == null || v.trim().isEmpty) return 'Title is required.';
    final t = v.trim();
    if (t.length < 5) return 'Title must be at least 5 characters.';
    if (t.length > 100) return 'Title must be at most 100 characters.';
    return null;
  }

  static String? validateDescription(String? v) {
    if (v == null || v.trim().isEmpty) return 'Description is required.';
    final t = v.trim();
    if (t.length < 30) return 'Description must be at least 30 characters.';
    if (t.length > 5000) return 'Description is too long (max 5000 characters).';
    return null;
  }

  static String? validateSkills(List<String> skills) {
    if (skills.isEmpty) return null; // skills are optional
    if (skills.length > 20) return 'Too many skills listed (max 20).';
    for (final s in skills) {
      if (s.trim().length > 50) {
        return 'Skill names must be 50 characters or fewer.';
      }
    }
    return null;
  }

  /// Maximum allowed job budget in RM — same cap as service prices.
  static const double maxBudget = 10000;

  static String? validateBudget(double? min, double? max) {
    if (max == null) return 'Please enter a budget.';
    if (min != null && min < 0) return 'Minimum budget cannot be negative.';
    if (max <= 0) return 'Budget must be greater than RM 0.';
    if (max > maxBudget) {
      return 'Budget cannot exceed RM ${maxBudget.toStringAsFixed(0)}.';
    }
    if (min != null && min > max) {
      return 'Minimum budget cannot exceed maximum budget.';
    }
    return null;
  }

  static String? validateBudgetField(String? v, {bool isMin = true}) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final amount = double.tryParse(v.trim());
    if (amount == null) return 'Enter a valid number.';
    if (isMin && amount < 0) return 'Cannot be negative.';
    if (!isMin && amount <= 0) return 'Must be greater than RM 0.';
    if (!isMin && amount > maxBudget) {
      return 'Budget cannot exceed RM ${maxBudget.toStringAsFixed(0)}.';
    }
    return null;
  }

  static String? validateDeadline(DateTime? deadline) {
    if (deadline == null) return null; // optional
    // Compare date-only — so "tomorrow" means the next calendar day,
    // regardless of what time of day the validation runs.
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
    if (!deadlineDate.isAfter(todayDate)) {
      return 'Deadline must be at least tomorrow.';
    }
    return null;
  }
}
