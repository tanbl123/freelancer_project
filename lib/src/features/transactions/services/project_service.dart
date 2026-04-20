import '../../../backend/shared/domain_types.dart';
import '../../../features/profile/models/profile_user.dart';
import '../models/milestone_item.dart';
import '../models/project_item.dart';
import '../repositories/project_repository.dart';

/// Business-logic layer for project lifecycle management.
class ProjectService {
  const ProjectService(this._repo);
  final ProjectRepository _repo;

  // ── Complete project (requires all milestones done + client signature) ──────

  Future<String?> completeProject(
    ProfileUser actor,
    ProjectItem project,
    List<MilestoneItem> milestones,
    String signatureUrl,
  ) async {
    if (actor.uid != project.clientId) return 'Only the client can complete the project.';

    final guard = canComplete(project, milestones);
    if (guard != null) return guard;

    try {
      await _repo.updateStatus(
        project.id,
        ProjectStatus.completed,
        clientSignatureUrl: signatureUrl,
      );
      return null;
    } catch (e) {
      return 'Failed to complete project: $e';
    }
  }

  // ── Cancel project ─────────────────────────────────────────────────────────

  Future<String?> cancelProject(
    ProfileUser actor,
    ProjectItem project, {
    String? reason,
  }) async {
    if (actor.uid != project.clientId &&
        actor.uid != project.freelancerId) {
      return 'Access denied.';
    }
    if (project.isCancelled) return 'This project has already been cancelled.';
    if (project.isCompleted) return 'Completed projects cannot be cancelled.';
    if (project.isDisputed) {
      return 'This project is under dispute and cannot be cancelled until the admin resolves it.';
    }

    try {
      await _repo.updateStatus(
        project.id,
        ProjectStatus.cancelled,
        cancellationReason: reason,
      );
      return null;
    } catch (e) {
      return 'Failed to cancel project: $e';
    }
  }

  // ── Dispute project ────────────────────────────────────────────────────────

  Future<String?> disputeProject(
    ProfileUser actor,
    ProjectItem project,
  ) async {
    if (actor.uid != project.clientId &&
        actor.uid != project.freelancerId) {
      return 'Access denied.';
    }
    if (!project.isInProgress) {
      return 'Only in-progress projects can be disputed.';
    }

    try {
      await _repo.updateStatus(project.id, ProjectStatus.disputed);
      return null;
    } catch (e) {
      return 'Failed to raise dispute: $e';
    }
  }

  // ── Guards (static — usable from UI without a service instance) ───────────

  /// Returns an error string when completion is blocked, null if OK.
  static String? canComplete(
    ProjectItem project,
    List<MilestoneItem> milestones,
  ) {
    if (!project.isInProgress) return 'Project is not currently in progress.';
    if (milestones.isEmpty) return 'No milestones have been defined.';
    final unfinished =
        milestones.where((m) => m.status != MilestoneStatus.completed).toList();
    if (unfinished.isNotEmpty) {
      return '${unfinished.length} milestone(s) are not yet completed.';
    }
    return null;
  }

  static bool allMilestonesCompleted(List<MilestoneItem> milestones) =>
      milestones.isNotEmpty &&
      milestones.every((m) => m.status == MilestoneStatus.completed);
}
