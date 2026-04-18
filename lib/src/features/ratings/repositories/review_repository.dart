import '../../../services/supabase_service.dart';
import '../../../shared/enums/review_status.dart';
import '../models/review_item.dart';

/// Thin data-access layer for reviews.
/// All persistence logic lives in [SupabaseService].
class ReviewRepository {
  const ReviewRepository(this._db);
  final SupabaseService _db;

  Future<List<ReviewItem>> getAll() => _db.getAllReviews();

  /// Published reviews where the current user is the reviewee.
  Future<List<ReviewItem>> getForUser(String userId) =>
      _db.getReviewsForUser(userId);

  /// All reviews (any status) written by [userId].
  Future<List<ReviewItem>> getByUser(String userId) =>
      _db.getReviewsByUser(userId);

  /// Reviews with [ReviewStatus.reported] — admin use.
  Future<List<ReviewItem>> getReported() => _db.getReportedReviews();

  Future<bool> hasReviewed(String projectId, String reviewerId) =>
      _db.hasReviewedProject(projectId, reviewerId);

  Future<void> insert(ReviewItem r) => _db.insertReview(r);

  Future<void> update(ReviewItem r) => _db.updateReview(r);

  /// Hard delete — call [setStatus] with [ReviewStatus.removed] for soft removal.
  Future<void> delete(String id) => _db.deleteReview(id);

  /// Append [reporterId] to `reported_by` and flip status to `reported`.
  Future<void> report(String reviewId, String reporterId) =>
      _db.reportReview(reviewId, reporterId);

  /// Admin: set review status (published / reported / removed).
  Future<void> setStatus(String reviewId, ReviewStatus status) =>
      _db.setReviewStatus(reviewId, status);

  /// Recalculate [averageRating] + [totalReviews] on the profile row.
  Future<void> updateStats(String userId) =>
      _db.updateRevieweeRatingStats(userId);

  Future<Map<int, int>> getRatingDistribution(String userId) =>
      _db.getRatingDistribution(userId);

  Future<Map<String, double>> getMonthlyEarnings(String userId) =>
      _db.getMonthlyEarnings(userId);

  Future<Map<String, double>> getMonthlyRatingTrend(String userId) =>
      _db.getMonthlyRatingTrend(userId);
}
