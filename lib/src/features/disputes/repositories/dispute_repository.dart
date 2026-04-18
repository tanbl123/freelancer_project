import '../../../services/supabase_service.dart';
import '../../../shared/enums/dispute_status.dart';
import '../models/dispute_record.dart';

/// Thin data-access wrapper for [DisputeRecord].
/// All business logic lives in [DisputeService].
class DisputeRepository {
  const DisputeRepository(this._db);
  final SupabaseService _db;

  Future<DisputeRecord?> getById(String id) =>
      _db.getDisputeById(id);

  Future<DisputeRecord?> getActiveForProject(String projectId) =>
      _db.getActiveDisputeForProject(projectId);

  Future<List<DisputeRecord>> getAllByStatus(DisputeStatus status) =>
      _db.getDisputesByStatus(status);

  Future<List<DisputeRecord>> getAllOpen() =>
      _db.getOpenDisputes();

  Future<List<DisputeRecord>> getForUser(String userId) =>
      _db.getDisputesForUser(userId);

  Future<void> insert(DisputeRecord record) =>
      _db.insertDisputeRecord(record);

  Future<void> update(DisputeRecord record) =>
      _db.updateDisputeRecord(record);
}
