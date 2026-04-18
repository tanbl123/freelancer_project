import '../../../services/supabase_service.dart';
import '../../../shared/enums/service_status.dart';
import '../models/freelancer_service.dart';

/// Thin data-access layer — delegates all I/O to [SupabaseService].
class FreelancerServiceRepository {
  const FreelancerServiceRepository(this._db);
  final SupabaseService _db;

  // ── Remote ────────────────────────────────────────────────────────────────

  Future<List<FreelancerService>> getActiveServices({
    String? search,
    String? category,
    double? maxPrice,
    int limit = 50,
    int offset = 0,
  }) =>
      _db.getActiveFreelancerServices(
        search: search,
        category: category,
        maxPrice: maxPrice,
        limit: limit,
        offset: offset,
      );

  Future<List<FreelancerService>> getServicesByFreelancer(
          String freelancerId) =>
      _db.getFreelancerServicesByOwner(freelancerId);

  Future<FreelancerService?> getById(String id) =>
      _db.getFreelancerServiceById(id);

  Future<FreelancerService> create(FreelancerService service) =>
      _db.insertFreelancerService(service);

  Future<FreelancerService> update(FreelancerService service) =>
      _db.updateFreelancerService(service);

  Future<void> updateStatus(String id, ServiceStatus status) =>
      _db.updateFreelancerServiceStatus(id, status);

  Future<void> incrementViewCount(String id) =>
      _db.incrementServiceViewCount(id);

  // ── Offline cache ─────────────────────────────────────────────────────────

  Future<List<FreelancerService>> getCached() =>
      _db.getCachedFreelancerServices();

  Future<void> cache(List<FreelancerService> services) =>
      _db.cacheFreelancerServices(services);
}
