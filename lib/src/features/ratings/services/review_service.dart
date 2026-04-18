import '../../../features/profile/models/profile_user.dart';
import '../../../features/transactions/models/project_item.dart';
import '../../../shared/enums/review_status.dart';
import '../../../shared/enums/user_role.dart';
import '../models/review_item.dart';
import '../repositories/review_repository.dart';

/// Business-logic layer for the Review & Rating system.
///
/// ## Permission matrix
/// | Action          | Who                              |
/// |-----------------|----------------------------------|
/// | Submit review   | Project participant after completion |
/// | Edit review     | Original reviewer only           |
/// | Delete review   | Original reviewer or admin       |
/// | Report review   | Any participant; not the author  |
/// | Remove (admin)  | Admin only                       |
/// | Restore (admin) | Admin only                       |
class ReviewService {
  const ReviewService(this._repo);
  final ReviewRepository _repo;

  // ── Guards ────────────────────────────────────────────────────────────────

  /// Whether [reviewer] may leave a new review for [project].
  bool canReview(ProfileUser reviewer, ProjectItem project) {
    if (!project.isCompleted) return false;
    return project.clientId == reviewer.uid ||
        project.freelancerId == reviewer.uid;
  }

  /// Whether [user] may edit [review].
  bool canEdit(ProfileUser user, ReviewItem review) =>
      review.reviewerId == user.uid && !review.isRemoved;

  /// Whether [user] may delete [review].
  bool canDelete(ProfileUser user, ReviewItem review) =>
      review.reviewerId == user.uid || user.role == UserRole.admin;

  /// Whether [user] may report [review].
  bool canReport(ProfileUser user, ReviewItem review) =>
      review.reviewerId != user.uid && !review.isReportedBy(user.uid);

  // ── Write operations ──────────────────────────────────────────────────────

  /// Submit a new review. Returns an error message or `null` on success.
  Future<String?> submit({
    required ReviewItem review,
    required ProfileUser reviewer,
    required ProjectItem project,
  }) async {
    if (!canReview(reviewer, project)) {
      return 'Reviews can only be submitted after a project is completed.';
    }
    if (review.stars < 1 || review.stars > 5) {
      return 'Rating must be between 1 and 5 stars.';
    }
    final alreadyReviewed =
        await _repo.hasReviewed(review.projectId, reviewer.uid);
    if (alreadyReviewed) {
      return 'You have already submitted a review for this project.';
    }

    await _repo.insert(review);
    await _repo.updateStats(review.revieweeId);
    return null;
  }

  /// Edit an existing review. Returns an error message or `null` on success.
  Future<String?> edit({
    required ReviewItem review,
    required ProfileUser editor,
    required int newStars,
    required String newComment,
  }) async {
    if (!canEdit(editor, review)) {
      return 'You can only edit your own reviews.';
    }
    if (newStars < 1 || newStars > 5) {
      return 'Rating must be between 1 and 5 stars.';
    }

    final updated = review.copyWith(stars: newStars, comment: newComment);
    await _repo.update(updated);
    await _repo.updateStats(review.revieweeId);
    return null;
  }

  /// Delete a review (hard delete). Returns an error message or `null`.
  Future<String?> remove({
    required ReviewItem review,
    required ProfileUser actor,
  }) async {
    if (!canDelete(actor, review)) {
      return 'You do not have permission to delete this review.';
    }
    await _repo.delete(review.id);
    await _repo.updateStats(review.revieweeId);
    return null;
  }

  /// Flag a review as inappropriate.
  Future<String?> report({
    required ReviewItem review,
    required ProfileUser reporter,
  }) async {
    if (!canReport(reporter, review)) {
      return 'You cannot report your own review or report it again.';
    }
    await _repo.report(review.id, reporter.uid);
    return null;
  }

  // ── Admin moderation ──────────────────────────────────────────────────────

  /// Set a review's status to [ReviewStatus.removed].
  Future<void> adminRemove(ReviewItem review) async {
    await _repo.setStatus(review.id, ReviewStatus.removed);
    await _repo.updateStats(review.revieweeId);
  }

  /// Restore a removed or reported review to [ReviewStatus.published].
  Future<void> adminRestore(ReviewItem review) async {
    await _repo.setStatus(review.id, ReviewStatus.published);
    await _repo.updateStats(review.revieweeId);
  }

  // ── Analytics pass-through ────────────────────────────────────────────────

  /// All reviews regardless of status — admin use.
  Future<List<ReviewItem>> getAll() => _repo.getAll();

  Future<List<ReviewItem>> getForUser(String userId) =>
      _repo.getForUser(userId);

  Future<List<ReviewItem>> getByUser(String userId) =>
      _repo.getByUser(userId);

  Future<List<ReviewItem>> getReported() => _repo.getReported();

  Future<Map<int, int>> getRatingDistribution(String userId) =>
      _repo.getRatingDistribution(userId);

  Future<Map<String, double>> getMonthlyEarnings(String userId) =>
      _repo.getMonthlyEarnings(userId);

  Future<Map<String, double>> getMonthlyRatingTrend(String userId) =>
      _repo.getMonthlyRatingTrend(userId);
}
