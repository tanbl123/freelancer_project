import '../../../services/supabase_service.dart';
import '../../../backend/shared/domain_types.dart';
import '../models/milestone_item.dart';

/// Thin data-access wrapper for milestones.
/// All business rules live in [MilestoneService].
class MilestoneRepository {
  const MilestoneRepository(this._db);
  final SupabaseService _db;

  Future<List<MilestoneItem>> getForProject(String projectId) =>
      _db.getMilestonesForProject(projectId);

  Future<void> insert(MilestoneItem m) => _db.insertMilestone(m);

  Future<void> insertBatch(List<MilestoneItem> milestones) =>
      _db.batchInsertMilestones(milestones);

  Future<void> update(MilestoneItem m) => _db.updateMilestone(m);

  Future<void> delete(String id) => _db.deleteMilestone(id);

  Future<void> updateStatus(String id, MilestoneStatus status) =>
      _db.updateMilestoneStatus(id, status);

  Future<void> approveMilestone(
          String id, String signatureUrl, String paymentToken) =>
      _db.approveMilestone(id, signatureUrl, paymentToken);

  Future<void> rejectMilestone(String id, String reason) =>
      _db.rejectMilestone(id, reason);

  Future<void> requestExtension(String id, int days) =>
      _db.requestMilestoneExtension(id, days);

  Future<void> approveExtension(String id, int days) =>
      _db.approveMilestoneExtension(id, days);

  Future<void> advanceToNext(
          String projectId, int completedOrderIndex) =>
      _db.advanceMilestoneToNext(projectId, completedOrderIndex);
}
