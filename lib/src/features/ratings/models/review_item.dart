import '../../../shared/enums/review_status.dart';

/// A review left by one project participant for the other.
///
/// Reviews are bidirectional:
/// - Client → Freelancer  (`reviewerId = clientId`,    `revieweeId = freelancerId`)
/// - Freelancer → Client  (`reviewerId = freelancerId`, `revieweeId = clientId`)
///
/// At most **one** review is allowed per (projectId, reviewerId) pair.
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.projectId,
    required this.reviewerId,
    required this.reviewerName,
    required this.revieweeId,
    required this.stars,
    this.comment = '',
    this.status = ReviewStatus.published,
    this.reportedBy = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;

  /// The person who wrote this review.
  final String reviewerId;
  final String reviewerName;

  /// The person being reviewed (freelancer or client).
  final String revieweeId;

  /// Rating from 1 to 5.
  final int stars;

  /// Optional written comment.
  final String comment;

  /// Moderation lifecycle.
  final ReviewStatus status;

  /// UIDs of users who flagged this review as inappropriate.
  final List<String> reportedBy;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Backward-compat alias ─────────────────────────────────────────────────

  /// Legacy alias kept for existing code that reads `freelancerId`.
  /// Equivalent to [revieweeId].
  String get freelancerId => revieweeId;

  // ── Convenience ───────────────────────────────────────────────────────────

  bool get isVisible  => status.isVisible;
  bool get isReported => status == ReviewStatus.reported;
  bool get isRemoved  => status == ReviewStatus.removed;

  bool isReportedBy(String userId) => reportedBy.contains(userId);

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'project_id': projectId,
      'reviewer_id': reviewerId,
      'reviewer_name': reviewerName,
      'reviewee_id': revieweeId,
      // Keep legacy column in sync for any old queries still using it.
      'freelancer_id': revieweeId,
      'stars': stars,
      'comment': comment,
      'status': status.name,
      'reported_by': reportedBy,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  factory ReviewItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    List<String> parseStringList(dynamic v) {
      if (v == null) return [];
      if (v is List) return List<String>.from(v);
      return [];
    }

    // Support old rows that have freelancer_id but not reviewee_id.
    final revieweeId =
        (map['reviewee_id'] as String?) ?? (map['freelancer_id'] as String? ?? '');

    return ReviewItem(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      reviewerName: map['reviewer_name'] as String? ?? '',
      revieweeId: revieweeId,
      stars: (map['stars'] as num).toInt(),
      comment: map['comment'] as String? ?? '',
      status: ReviewStatus.fromString(map['status'] as String? ?? 'published'),
      reportedBy: parseStringList(map['reported_by']),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  ReviewItem copyWith({
    int? stars,
    String? comment,
    ReviewStatus? status,
    List<String>? reportedBy,
  }) {
    return ReviewItem(
      id: id,
      projectId: projectId,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      revieweeId: revieweeId,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      status: status ?? this.status,
      reportedBy: reportedBy ?? this.reportedBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
