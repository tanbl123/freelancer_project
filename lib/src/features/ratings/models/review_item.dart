import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory ReviewItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ReviewItem(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      reviewerId: data['reviewerId'] as String? ?? '',
      freelancerId: data['freelancerId'] as String? ?? '',
      stars: data['stars'] as int? ?? 0,
      comment: data['comment'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'projectId': projectId,
      'reviewerId': reviewerId,
      'freelancerId': freelancerId,
      'stars': stars,
      'comment': comment,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
