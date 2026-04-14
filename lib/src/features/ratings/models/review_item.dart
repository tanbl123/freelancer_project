class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.projectId,
    required this.reviewerId,
    required this.freelancerId,
    required this.stars,
    required this.comment,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String reviewerId;
  final String freelancerId;
  final int stars;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Supabase map (ISO 8601) ──────────────────────────────────────────────────
  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'project_id': projectId,
      'reviewer_id': reviewerId,
      'freelancer_id': freelancerId,
      'stars': stars,
      'comment': comment,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  // ── SQLite map (epoch ms) ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'project_id': projectId,
      'reviewer_id': reviewerId,
      'freelancer_id': freelancerId,
      'stars': stars,
      'comment': comment,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  // ── Dual-format fromMap ──────────────────────────────────────────────────────
  factory ReviewItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ReviewItem(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      stars: (map['stars'] as num).toInt(),
      comment: map['comment'] as String,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  ReviewItem copyWith({
    int? stars,
    String? comment,
  }) {
    return ReviewItem(
      id: id,
      projectId: projectId,
      reviewerId: reviewerId,
      freelancerId: freelancerId,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
