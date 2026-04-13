import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/ratings/models/review_item.dart';
import '../shared/domain_types.dart';
import '../shared/firestore_paths.dart';

class RatingsRepository {
  RatingsRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reviews => _firestore.collection(FirestorePaths.reviews);

  Stream<List<ReviewItem>> streamFreelancerReviews(String freelancerId) {
    return _reviews
        .where('freelancerId', isEqualTo: freelancerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ReviewItem.fromFirestore).toList());
  }

  Future<String> createReview(ReviewItem review) async {
    final orderQuery = await _firestore
        .collection(FirestorePaths.projects)
        .where('jobId', isEqualTo: review.projectId)
        .where('clientId', isEqualTo: review.reviewerId)
        .where('freelancerId', isEqualTo: review.freelancerId)
        .where('status', isEqualTo: OrderStatus.completed.name)
        .limit(1)
        .get();

    if (orderQuery.docs.isEmpty) {
      throw StateError('Review requires a completed project between both users.');
    }

    final existing = await _reviews
        .where('projectId', isEqualTo: review.projectId)
        .where('reviewerId', isEqualTo: review.reviewerId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw StateError('A review already exists for this project by the same user.');
    }

    final ref = await _reviews.add(review.toFirestore());
    await _refreshFreelancerStats(review.freelancerId);
    return ref.id;
  }

  Future<void> updateReview(ReviewItem review) async {
    await _reviews.doc(review.id).update(review.toFirestore());
    await _refreshFreelancerStats(review.freelancerId);
  }

  Future<void> deleteReview(ReviewItem review) async {
    await _reviews.doc(review.id).delete();
    await _refreshFreelancerStats(review.freelancerId);
  }

  Future<void> _refreshFreelancerStats(String freelancerId) async {
    final reviews = await _reviews.where('freelancerId', isEqualTo: freelancerId).get();
    if (reviews.docs.isEmpty) {
      await _firestore.collection(FirestorePaths.users).doc(freelancerId).update({
        'averageRating': 0,
        'totalReviews': 0,
      });
      return;
    }

    final stars = reviews.docs
        .map((doc) => (doc.data()['stars'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (sum, value) => sum + value);

    await _firestore.collection(FirestorePaths.users).doc(freelancerId).update({
      'averageRating': stars / reviews.docs.length,
      'totalReviews': reviews.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
