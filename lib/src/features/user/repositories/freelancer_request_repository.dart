import '../../../services/supabase_service.dart';
import '../../../shared/enums/request_status.dart';
import '../models/freelancer_request.dart';

class FreelancerRequestRepository {
  final SupabaseService _db;
  FreelancerRequestRepository(this._db);

  Future<FreelancerRequest?> getPending(String userId) =>
      _db.getPendingFreelancerRequest(userId);

  Future<FreelancerRequest?> getLatest(String userId) =>
      _db.getLatestFreelancerRequest(userId);

  Future<List<FreelancerRequest>> getAll({RequestStatus? status}) =>
      _db.getAllFreelancerRequests(status: status);

  Future<FreelancerRequest> create(FreelancerRequest req) =>
      _db.insertFreelancerRequest(req);

  Future<FreelancerRequest> updateStatus(
    String id,
    RequestStatus status, {
    String? adminNote,
    String? reviewedBy,
  }) =>
      _db.updateFreelancerRequestStatus(
        id,
        status,
        adminNote: adminNote,
        reviewedBy: reviewedBy,
      );
}
