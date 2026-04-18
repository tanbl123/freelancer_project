import '../../../services/supabase_service.dart';
import '../../../backend/shared/domain_types.dart';
import '../models/project_item.dart';

/// Thin data-access wrapper for projects.
/// All business rules live in [ProjectService].
class ProjectRepository {
  const ProjectRepository(this._db);
  final SupabaseService _db;

  Future<List<ProjectItem>> getForUser(String uid) =>
      _db.getProjectsForUser(uid);

  Future<ProjectItem?> getById(String id) =>
      _db.getProjectById(id);

  Future<void> insert(ProjectItem project) =>
      _db.insertProject(project);

  Future<void> updateStatus(
    String id,
    ProjectStatus status, {
    String? clientSignatureUrl,
    DateTime? startDate,
  }) =>
      _db.updateProjectStatusEnum(
        id,
        status,
        clientSignatureUrl: clientSignatureUrl,
        startDate: startDate,
      );

  Future<void> update(ProjectItem project) =>
      _db.updateProject(project);
}
