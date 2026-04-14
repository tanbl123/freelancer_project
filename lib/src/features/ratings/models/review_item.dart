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

  factory ReviewItem.fromMap(Map<String, dynamic> map) {
    return ReviewItem(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      stars: map['stars'] as int,
      comment: map['comment'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
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
