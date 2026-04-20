import '../../../backend/shared/domain_types.dart';
import '../../../features/profile/models/profile_user.dart';
import '../models/milestone_item.dart';
import '../models/project_item.dart';
import '../repositories/milestone_repository.dart';
import '../repositories/project_repository.dart';

/// Business-logic layer for milestones and the plan lifecycle.
///
/// State machine:
/// ```
/// [freelancer proposes] → pendingApproval
///   ↓ client approves plan
/// first milestone → inProgress
/// rest           → approved
///   ↓ freelancer submits deliverable
/// inProgress → submitted
///   ↓ client approves + sign + pay
/// submitted → completed  (next approved milestone → inProgress)
///   ↓ client rejects
/// submitted → rejected
///   ↓ freelancer revises
/// rejected → inProgress
/// ```
///
/// ## Ownership enforcement
/// Every method that accepts a [ProfileUser] actor **loads the parent project
/// from the repository** and verifies the actor's UID against
/// `project.freelancerId` or `project.clientId`, as appropriate.  This means
/// ownership is enforced at the service layer rather than relying solely on
/// the caller (AppState) to pre-check.
class MilestoneService {
  const MilestoneService(this._milestoneRepo, this._projectRepo);
  final MilestoneRepository _milestoneRepo;
  final ProjectRepository _projectRepo;

  // ── Plan proposal ──────────────────────────────────────────────────────────

  /// Freelancer proposes the full milestone plan.
  /// Inserts all milestones with [MilestoneStatus.pendingApproval].
  Future<String?> proposePlan(
    ProfileUser actor,
    ProjectItem project,
    List<MilestoneItem> milestones,
  ) async {
    if (actor.uid != project.freelancerId) return 'Access denied.';
    if (!project.isPendingStart) {
      return 'Milestone plan can only be proposed for pending projects.';
    }
    final err = validatePlan(milestones, project);
    if (err != null) return err;

    try {
      // Delete any existing (rejected) plan milestones first.
      final existing = await _milestoneRepo.getForProject(project.id);
      for (final m in existing) {
        await _milestoneRepo.delete(m.id);
      }
      await _milestoneRepo.insertBatch(milestones);
      return null;
    } catch (e) {
      return 'Failed to propose plan: $e';
    }
  }

  // ── Plan approval ──────────────────────────────────────────────────────────

  /// Client approves the full milestone plan.
  /// First milestone → inProgress; rest → approved; project → inProgress.
  Future<String?> approvePlan(
    ProfileUser actor,
    ProjectItem project,
    List<MilestoneItem> milestones,
  ) async {
    if (actor.uid != project.clientId) return 'Access denied.';
    if (!project.isPendingStart) return 'Nothing to approve.';
    if (milestones.isEmpty) return 'No milestones to approve.';
    if (milestones.any((m) => m.status != MilestoneStatus.pendingApproval)) {
      return 'All milestones must be in pending-approval state.';
    }

    try {
      final sorted = List<MilestoneItem>.from(milestones)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (int i = 0; i < sorted.length; i++) {
        final newStatus =
            i == 0 ? MilestoneStatus.inProgress : MilestoneStatus.approved;
        await _milestoneRepo.updateStatus(sorted[i].id, newStatus);
      }

      await _projectRepo.updateStatus(
        project.id,
        ProjectStatus.inProgress,
        startDate: DateTime.now(),
      );
      return null;
    } catch (e) {
      return 'Failed to approve plan: $e';
    }
  }

  // ── Plan rejection ─────────────────────────────────────────────────────────

  /// Client rejects the whole milestone plan — milestones are deleted so the
  /// freelancer can re-propose a revised plan.
  Future<String?> rejectPlan(
    ProfileUser actor,
    ProjectItem project,
    List<MilestoneItem> milestones,
  ) async {
    if (actor.uid != project.clientId) return 'Access denied.';
    if (!project.isPendingStart) return 'Nothing to reject.';

    try {
      for (final m in milestones) {
        await _milestoneRepo.delete(m.id);
      }
      return null;
    } catch (e) {
      return 'Failed to reject plan: $e';
    }
  }

  // ── Deliverable submission ─────────────────────────────────────────────────

  /// Freelancer submits the deliverable for the current inProgress milestone.
  ///
  /// Ownership is verified against the parent project — the method loads the
  /// project from the repository and checks [actor.uid] == [ProjectItem.freelancerId].
  Future<String?> submitDeliverable(
    ProfileUser actor,
    MilestoneItem milestone,
    String deliverableUrl,
  ) async {
    final project = await _projectRepo.getById(milestone.projectId);
    if (project == null) return 'Project not found.';
    if (actor.uid != project.freelancerId) return 'Access denied.';

    if (!milestone.isInProgress) {
      return 'Only in-progress milestones can be submitted.';
    }
    if (deliverableUrl.trim().isEmpty) {
      return 'Please provide a deliverable link or description.';
    }

    try {
      await _milestoneRepo.update(
        milestone.copyWith(
          status: MilestoneStatus.submitted,
          deliverableUrl: deliverableUrl.trim(),
        ),
      );
      return null;
    } catch (e) {
      return 'Failed to submit deliverable: $e';
    }
  }

  // ── Approve deliverable (client) ───────────────────────────────────────────

  /// Client approves the submitted deliverable: signs + pays.
  /// Auto-advances the next approved milestone to inProgress.
  ///
  /// Verifies [actor] is the project client.
  Future<String?> approveMilestone(
    ProfileUser actor,
    MilestoneItem milestone,
    String signaturePath,
    String paymentToken,
  ) async {
    final project = await _projectRepo.getById(milestone.projectId);
    if (project == null) return 'Project not found.';
    if (actor.uid != project.clientId) return 'Access denied.';

    if (!milestone.isSubmitted) {
      return 'Milestone must be submitted before it can be approved.';
    }

    try {
      await _milestoneRepo.approveMilestone(
          milestone.id, signaturePath, paymentToken);

      // Advance the next queued milestone.
      await _milestoneRepo.advanceToNext(
          milestone.projectId, milestone.orderIndex);

      return null;
    } catch (e) {
      return 'Failed to approve milestone: $e';
    }
  }

  // ── Reject deliverable (client) ────────────────────────────────────────────

  /// Verifies [actor] is the project client.
  Future<String?> rejectMilestone(
    ProfileUser actor,
    MilestoneItem milestone,
    String reason,
  ) async {
    final project = await _projectRepo.getById(milestone.projectId);
    if (project == null) return 'Project not found.';
    if (actor.uid != project.clientId) return 'Access denied.';

    if (!milestone.isSubmitted) {
      return 'Milestone must be submitted before it can be rejected.';
    }
    if (reason.trim().isEmpty) return 'Please provide a rejection reason.';

    try {
      await _milestoneRepo.rejectMilestone(milestone.id, reason.trim());
      return null;
    } catch (e) {
      return 'Failed to reject milestone: $e';
    }
  }

  // ── Revise after rejection (freelancer) ───────────────────────────────────

  /// Verifies [actor] is the project freelancer.
  Future<String?> reviseMilestone(
    ProfileUser actor,
    MilestoneItem milestone,
  ) async {
    final project = await _projectRepo.getById(milestone.projectId);
    if (project == null) return 'Project not found.';
    if (actor.uid != project.freelancerId) return 'Access denied.';

    if (!milestone.isRejected) {
      return 'Only rejected milestones can be revised.';
    }

    try {
      await _milestoneRepo.update(
        milestone.copyWith(
          status: MilestoneStatus.inProgress,
          revisionCount: milestone.revisionCount + 1,
          rejectionNote: null,
        ),
      );
      return null;
    } catch (e) {
      return 'Failed to revise milestone: $e';
    }
  }

  // ── Extension request (freelancer) ────────────────────────────────────────

  /// Verifies [actor] is the project freelancer.
  Future<String?> requestExtension(
    ProfileUser actor,
    MilestoneItem milestone,
    int days,
  ) async {
    final project = await _projectRepo.getById(milestone.projectId);
    if (project == null) return 'Project not found.';
    if (actor.uid != project.freelancerId) return 'Access denied.';

    if (!milestone.isInProgress) {
      return 'Extensions can only be requested for in-progress milestones.';
    }
    if (days < 1 || days > 90) {
      return 'Extension must be between 1 and 90 days.';
    }
    if (milestone.extensionRequestedAt != null &&
        !milestone.extensionApproved) {
      return 'An extension request is already pending.';
    }

    try {
      await _milestoneRepo.requestExtension(milestone.id, days);
      return null;
    } catch (e) {
      return 'Failed to request extension: $e';
    }
  }

  // ── Approve extension (client) ─────────────────────────────────────────────

  /// Verifies [actor] is the project client.
  Future<String?> approveExtension(
    ProfileUser actor,
    MilestoneItem milestone,
  ) async {
    final project = await _projectRepo.getById(milestone.projectId);
    if (project == null) return 'Project not found.';
    if (actor.uid != project.clientId) return 'Access denied.';

    if (milestone.extensionRequestedAt == null) {
      return 'No extension request found.';
    }
    if (milestone.extensionApproved) return 'Extension already approved.';

    try {
      await _milestoneRepo.approveExtension(
          milestone.id, milestone.extensionDays ?? 0);
      return null;
    } catch (e) {
      return 'Failed to approve extension: $e';
    }
  }

  // ── Plan validation (static) ───────────────────────────────────────────────

  /// Returns an error string or null if the plan is valid.
  static const int maxMilestones = 10;

  static String? validatePlan(
    List<MilestoneItem> milestones,
    ProjectItem project,
  ) {
    if (milestones.length < 2) {
      return 'A minimum of 2 milestones is required.';
    }
    if (milestones.length > maxMilestones) {
      return 'A plan cannot have more than $maxMilestones milestones.';
    }

    final totalPct =
        milestones.fold<double>(0.0, (s, m) => s + m.percentage);
    if ((totalPct - 100.0).abs() > 0.01) {
      return 'Milestone percentages must total exactly 100% '
          '(currently ${totalPct.toStringAsFixed(1)}%).';
    }

    // Must be ordered by deadline
    final sorted = List<MilestoneItem>.from(milestones)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    for (int i = 1; i < sorted.length; i++) {
      if (!sorted[i].deadline.isAfter(sorted[i - 1].deadline)) {
        return 'Milestone ${sorted[i].orderIndex} deadline must be after '
            'milestone ${sorted[i - 1].orderIndex}.';
      }
    }

    // Deadlines must not precede project start
    if (project.startDate != null) {
      for (final m in milestones) {
        if (m.deadline.isBefore(project.startDate!)) {
          return '"${m.title}" deadline cannot be before the project start date.';
        }
      }
    }

    // Deadlines must not exceed project end date
    if (project.endDate != null) {
      for (final m in milestones) {
        if (m.deadline.isAfter(project.endDate!)) {
          return '"${m.title}" deadline (${_fmt(m.deadline)}) exceeds '
              'the project end date (${_fmt(project.endDate!)}).';
        }
      }
    }

    // Individual percentage bounds
    for (final m in milestones) {
      if (m.percentage <= 0 || m.percentage > 100) {
        return '"${m.title}" percentage must be between 1 and 100.';
      }
    }

    return null;
  }

  static String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
