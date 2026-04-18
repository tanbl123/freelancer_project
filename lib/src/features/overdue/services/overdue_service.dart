import 'package:uuid/uuid.dart';

import '../../../shared/enums/overdue_status.dart';
import '../../transactions/models/milestone_item.dart';
import '../../transactions/models/project_item.dart';
import '../models/overdue_record.dart';
import '../repositories/overdue_repository.dart';

// ── Action returned by checkMilestone ─────────────────────────────────────────

/// Describes what the overdue check determined should happen for a milestone.
enum OverdueAction {
  none,      // deadline not reached, or already handled
  warn3Days, // send 3-day warning notifications
  warn1Day,  // send 1-day warning notifications
  finalWarn, // send final-warning notifications (deadline passed, grace starts)
  enforce,   // auto-cancel project + restrict freelancer + refund escrow
  resolved,  // milestone completed — mark overdue record as auto-resolved
}

// ── Service ────────────────────────────────────────────────────────────────────

/// Business-logic layer for the overdue-warning pipeline.
///
/// ## Warning stages (based on time-to-effective-deadline)
/// | Stage           | Condition                            |
/// |-----------------|--------------------------------------|
/// | onTrack         | > 3 days remaining                   |
/// | warning3Days    | ≤ 3 days and > 1 day remaining       |
/// | warning1Day     | ≤ 1 day remaining (not yet passed)   |
/// | finalWarning    | deadline passed, within grace period  |
/// | triggered       | beyond grace period → enforcement     |
///
/// ## Enforcement (triggered stage)
/// 1. Project status → cancelled
/// 2. Freelancer account_status → restricted
/// 3. Remaining escrow → refunded to client
///
/// ## Scheduler strategy
/// This service is designed to be called:
/// - From a [Timer.periodic] every 30 minutes while the app is foregrounded
///   ([AppState.startOverdueChecker])
/// - On app resume ([WidgetsBindingObserver.didChangeAppLifecycleState])
/// - From a Supabase Edge Function + pg_cron (hourly, for background checks)
class OverdueService {
  const OverdueService(this._repo);
  final OverdueRepository _repo;

  static const _uuid = Uuid();

  /// Hours beyond the deadline before auto-enforcement fires.
  static const int gracePeriodHours = 24;

  /// Days-remaining threshold for the first warning.
  static const int warn3DaysThreshold = 3;

  /// Days-remaining threshold for the second warning.
  static const int warn1DayThreshold = 1;

  // ── Pure calculation (no I/O) ──────────────────────────────────────────────

  /// Compute which warning stage a milestone is currently in.
  ///
  /// Milestones that are already [MilestoneStatus.completed] always return
  /// [OverdueStatus.onTrack] regardless of time.
  static OverdueStatus computeWarningStatus(MilestoneItem milestone) {
    if (milestone.isCompleted) return OverdueStatus.onTrack;

    final now = DateTime.now();
    final deadline = milestone.effectiveDeadline;
    final hoursUntil = deadline.difference(now).inHours;
    final daysUntil = deadline.difference(now).inDays;

    if (hoursUntil > warn3DaysThreshold * 24) return OverdueStatus.onTrack;
    if (daysUntil >= warn1DayThreshold)       return OverdueStatus.warning3Days;
    if (hoursUntil >= 0)                      return OverdueStatus.warning1Day;
    if (-hoursUntil < gracePeriodHours)       return OverdueStatus.finalWarning;
    return OverdueStatus.triggered;
  }

  /// How many days until the milestone's effective deadline.
  /// Negative values mean the deadline has passed.
  static int daysUntilDeadline(MilestoneItem milestone) =>
      milestone.effectiveDeadline.difference(DateTime.now()).inDays;

  /// Human-readable countdown string, e.g. "3 days left" or "2 days overdue".
  static String deadlineLabel(MilestoneItem milestone) {
    final days = daysUntilDeadline(milestone);
    if (milestone.isCompleted) return 'Completed';
    if (days > 0) return '$days day${days == 1 ? '' : 's'} left';
    if (days == 0) return 'Due today';
    return '${-days} day${-days == 1 ? '' : 's'} overdue';
  }

  // ── I/O operations ─────────────────────────────────────────────────────────

  /// Check a single milestone and determine what action is needed.
  ///
  /// This is idempotent: calling it multiple times with the same milestone
  /// state will not send duplicate warnings (each warning stage is gated by
  /// the `warningXxxSentAt` timestamps in the [OverdueRecord]).
  ///
  /// Returns an [OverdueAction] the caller should act on.
  Future<OverdueAction> checkMilestone({
    required MilestoneItem milestone,
    required ProjectItem project,
    required OverdueRecord? existingRecord,
  }) async {
    // Already enforced — nothing further to do.
    if (existingRecord?.status == OverdueStatus.triggered) {
      return OverdueAction.none;
    }

    // Milestone completed before enforcement → mark resolved.
    if (milestone.isCompleted) {
      if (existingRecord != null && !existingRecord.autoResolved) {
        await _repo.markResolved(existingRecord.id);
        return OverdueAction.resolved;
      }
      return OverdueAction.none;
    }

    final newStatus = computeWarningStatus(milestone);
    if (newStatus == OverdueStatus.onTrack) return OverdueAction.none;

    // Map status → action, guarded by "already sent" flags.
    final action = _resolveAction(newStatus, existingRecord);
    if (action == OverdueAction.none) return OverdueAction.none;

    // Persist the updated overdue record.
    await _upsertRecord(milestone, project, existingRecord, newStatus, action);

    return action;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  OverdueAction _resolveAction(
      OverdueStatus newStatus, OverdueRecord? existing) {
    switch (newStatus) {
      case OverdueStatus.warning3Days:
        if (existing?.warningFirstSentAt == null) return OverdueAction.warn3Days;
      case OverdueStatus.warning1Day:
        if (existing?.warningSecondSentAt == null) return OverdueAction.warn1Day;
      case OverdueStatus.finalWarning:
        if (existing?.finalWarningAt == null) return OverdueAction.finalWarn;
      case OverdueStatus.triggered:
        if (existing?.triggeredAt == null) return OverdueAction.enforce;
      case OverdueStatus.onTrack:
        break;
    }
    return OverdueAction.none;
  }

  Future<void> _upsertRecord(
    MilestoneItem milestone,
    ProjectItem project,
    OverdueRecord? existing,
    OverdueStatus newStatus,
    OverdueAction action,
  ) async {
    final now = DateTime.now();

    if (existing == null) {
      await _repo.insert(OverdueRecord(
        id: _uuid.v4(),
        projectId: milestone.projectId,
        milestoneId: milestone.id,
        freelancerId: project.freelancerId,
        clientId: project.clientId,
        status: newStatus,
        milestoneDeadline: milestone.effectiveDeadline,
        warningFirstSentAt:
            action == OverdueAction.warn3Days ? now : null,
        warningSecondSentAt:
            action == OverdueAction.warn1Day ? now : null,
        finalWarningAt:
            action == OverdueAction.finalWarn ? now : null,
        triggeredAt:
            action == OverdueAction.enforce ? now : null,
        autoResolved: false,
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await _repo.update(existing.copyWith(
        status: newStatus,
        milestoneDeadline: milestone.effectiveDeadline,
        warningFirstSentAt: existing.warningFirstSentAt ??
            (action == OverdueAction.warn3Days ? now : null),
        warningSecondSentAt: existing.warningSecondSentAt ??
            (action == OverdueAction.warn1Day ? now : null),
        finalWarningAt: existing.finalWarningAt ??
            (action == OverdueAction.finalWarn ? now : null),
        triggeredAt: existing.triggeredAt ??
            (action == OverdueAction.enforce ? now : null),
      ));
    }
  }
}
