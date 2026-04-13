import '../../../backend/marketplace/marketplace_repository.dart';
import '../models/marketplace_post.dart';
import '../../../backend/shared/domain_types.dart';

class MarketplaceController {
  MarketplaceController({MarketplaceRepository? repository}) : _repository = repository ?? MarketplaceRepository();

  final MarketplaceRepository _repository;

  Stream<List<MarketplacePost>> streamActiveFeed(PostType type) => _repository.streamActiveFeed(type);

  Future<String> createPost(MarketplacePost post) => _repository.createPost(post);

  Future<void> updatePost(MarketplacePost post) => _repository.updatePost(post);

  Future<void> deletePost({required String postId, required PostType type}) =>
      _repository.deletePost(postId: postId, type: type);

  Future<void> syncOfflineJobsCache() => _repository.cacheLatestJobs();

  Future<List<Map<String, dynamic>>> readOfflineJobs() => _repository.readCachedJobs();
}
