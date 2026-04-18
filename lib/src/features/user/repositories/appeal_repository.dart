import '../../../services/supabase_service.dart';
import '../../../shared/enums/appeal_status.dart';
import '../models/appeal.dart';

class AppealRepository {
  final SupabaseService _db;
  AppealRepository(this._db);

  Future<List<Appeal>> getForUser(String userId) =>
      _db.getAppealsForUser(userId);

  Future<Appeal?> getOpenForUser(String userId) =>
      _db.getOpenAppealForUser(userId);

  Future<List<Appeal>> getAll({AppealStatus? status}) =>
      _db.getAllAppeals(status: status);

  Future<Appeal> create(Appeal appeal) => _db.insertAppeal(appeal);

  Future<Appeal> updateStatus(
    String id,
    AppealStatus status, {
    String? adminResponse,
    String? reviewedBy,
  }) =>
      _db.updateAppealStatus(
        id,
        status,
        adminResponse: adminResponse,
        reviewedBy: reviewedBy,
      );
}
