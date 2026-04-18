import '../../../services/supabase_service.dart';
import '../models/overdue_record.dart';

/// Thin data-access wrapper for [OverdueRecord].
/// All business logic lives in [OverdueService].
class OverdueRepository {
  const OverdueRepository(this._db);
  final SupabaseService _db;

  Future<OverdueRecord?> getForMilestone(String milestoneId) =>
      _db.getOverdueRecordForMilestone(milestoneId);

  Future<List<OverdueRecord>> getActiveForProject(String projectId) =>
      _db.getActiveOverdueRecordsForProject(projectId);

  Future<List<OverdueRecord>> getAllActive() =>
      _db.getAllActiveOverdueRecords();

  Future<void> insert(OverdueRecord record) =>
      _db.insertOverdueRecord(record);

  Future<void> update(OverdueRecord record) =>
      _db.updateOverdueRecord(record);

  Future<void> markResolved(String id) =>
      _db.markOverdueRecordResolved(id);
}
