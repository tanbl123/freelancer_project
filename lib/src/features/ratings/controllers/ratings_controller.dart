import '../../../backend/ratings/ratings_repository.dart';
import '../models/review_item.dart';

class RatingsController {
  RatingsController({RatingsRepository? repository}) : _repository = repository ?? RatingsRepository();

  final RatingsRepository _repository;

  Stream<List<ReviewItem>> streamFreelancerReviews(String freelancerId) =>
      _repository.streamFreelancerReviews(freelancerId);

  Future<String> createReview(ReviewItem review) => _repository.createReview(review);

  Future<void> updateReview(ReviewItem review) => _repository.updateReview(review);

  Future<void> deleteReview(ReviewItem review) => _repository.deleteReview(review);
}
