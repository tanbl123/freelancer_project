import '../../../services/supabase_service.dart';
import '../../../shared/enums/job_status.dart';
import '../models/job_post.dart';

/// Thin data-access wrapper — all Supabase calls go through [SupabaseService].
/// Business rules live in [JobPostService], not here.
class JobPostRepository {
  const JobPostRepository(this._db);

  final SupabaseService _db;

  // ── Remote (Supabase) ─────────────────────────────────────────────────────

  Future<List<JobPost>> getOpenPosts({
    String? search,
    String? category,
    double? minBudget,
    double? maxBudget,
    int limit = 50,
    int offset = 0,
  }) =>
      _db.getOpenJobPosts(
        search: search,
        category: category,
        minBudget: minBudget,
        maxBudget: maxBudget,
        limit: limit,
        offset: offset,
      );

  Future<List<JobPost>> getPostsByClient(String clientId) =>
      _db.getJobPostsByClient(clientId);

  Future<JobPost?> getById(String id) => _db.getJobPostById(id);

  Future<JobPost> create(JobPost post) => _db.insertJobPost(post);

  Future<JobPost> update(JobPost post) => _db.updateJobPost(post);

  Future<void> updateStatus(String id, JobStatus status) =>
      _db.updateJobPostStatus(id, status);

  /// Soft-deletes by setting status = deleted (delegates to [SupabaseService.deleteJobPost]).
  Future<void> delete(String id) => _db.deleteJobPost(id);

  Future<void> incrementViewCount(String id) =>
      _db.incrementJobPostViewCount(id);

  // ── Offline cache (SQLite via JobCacheDao) ───────────────────────────────

  Future<List<JobPost>> getCached() => _db.getCachedJobPosts();

  Future<void> cache(List<JobPost> posts) => _db.cacheJobPosts(posts);

  /// Timestamp of the last successful Supabase sync. `null` = never synced.
  Future<DateTime?> getCacheLastSyncedAt() => _db.getJobCacheLastSyncedAt();

  /// `true` when the cache is older than [JobCacheDao.kStaleDuration].
  Future<bool> isCacheStale() => _db.isJobCacheStale();

  /// Clear the local cache — call on user logout.
  Future<void> clearCache() => _db.jobCacheDao.clear();
}
