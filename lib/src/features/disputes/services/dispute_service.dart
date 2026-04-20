import 'package:uuid/uuid.dart';

import '../../../shared/enums/dispute_reason.dart';
import '../../../shared/enums/dispute_resolution.dart';
import '../../../shared/enums/dispute_status.dart';
import '../../../shared/enums/payment_status.dart';
import '../../../shared/enums/payout_status.dart';
import '../../../shared/enums/project_status.dart';
import '../../payment/models/payment_record.dart';
import '../../payment/models/payout_record.dart';
import '../../payment/repositories/payment_repository.dart';
import '../../payment/services/payment_service.dart';
import '../../profile/models/profile_user.dart';
import '../../transactions/models/project_item.dart';
import '../../transactions/repositories/project_repository.dart';
import '../models/dispute_record.dart';
import '../repositories/dispute_repository.dart';

/// Result returned by [DisputeService.processResolution].
class DisputeResolutionResult {
  const DisputeResolutionResult({
    required this.dispute,
    required this.payment,
    this.disputePayout,
  });

  /// The updated (resolved/closed) dispute record.
  final DisputeRecord dispute;

  /// The adjusted payment record after funds were moved.
  final PaymentRecord payment;

  /// A payout record created if any funds were released to the freelancer.
  /// Null for [DisputeResolution.fullRefundToClient] and [DisputeResolution.noAction].
  final PayoutRecord? disputePayout;
}

/// Business-logic layer for the dispute system.
///
/// ## Raising a dispute
/// Any active party (client or freelancer) may raise a dispute. The project
/// is immediately moved to [ProjectStatus.disputed], which pauses all further
/// milestone approvals and payment releases until the admin resolves it.
///
/// ## Admin resolution
/// The admin reviews the evidence and chooses one of four strategies:
///
/// | Resolution                  | Effect on remaining escrow                              |
/// |-----------------------------|----------------------------------------------------------|
/// | fullRefundToClient          | 100 % → client. Platform fee: none.                      |
/// | partialSplit                | Admin specifies client portion; rest → freelancer (−10%). |
/// | fullReleaseToFreelancer     | 100 % → freelancer (−10% platform fee).                  |
/// | noAction                    | No payment changes. Dispute closed as informational.      |
///
/// After resolution the project is moved to [ProjectStatus.cancelled]
/// (except [noAction] which leaves the project as-is for manual handling).
class DisputeService {
  const DisputeService(
    this._disputeRepo,
    this._projectRepo,
    this._paymentRepo,
  );

  final DisputeRepository _disputeRepo;
  final ProjectRepository _projectRepo;
  final PaymentRepository _paymentRepo;

  static const _uuid = Uuid();

  // ── Raise dispute ──────────────────────────────────────────────────────────

  /// Create a dispute and pause the project.
  ///
  /// Validates:
  /// - Actor is client or freelancer of the project.
  /// - Project is in a disputable state (in-progress, pending-start, cancelled).
  /// - No open dispute already exists for this project.
  ///
  /// Returns the created [DisputeRecord] or throws on error.
  Future<DisputeRecord> raiseDispute({
    required ProfileUser actor,
    required ProjectItem project,
    required DisputeReason reason,
    required String description,
    List<String> evidenceUrls = const [],
  }) async {
    // ── Guards ──────────────────────────────────────────────────────────────

    if (actor.uid != project.clientId &&
        actor.uid != project.freelancerId) {
      throw Exception('Access denied: you are not a party to this project.');
    }

    if (project.isCompleted) {
      throw Exception(
          'Completed projects cannot be disputed. '
          'Contact support if you have concerns.');
    }

    if (project.isDisputed) {
      throw Exception(
          'A dispute is already open for this project. '
          'View the existing dispute for status updates.');
    }

    if (description.trim().length < 20) {
      throw Exception(
          'Please provide a more detailed description (at least 20 characters).');
    }

    // ── Create dispute record ────────────────────────────────────────────────

    final record = DisputeRecord(
      id: _uuid.v4(),
      projectId: project.id,
      raisedById: actor.uid,
      clientId: project.clientId,
      freelancerId: project.freelancerId,
      status: DisputeStatus.open,
      reason: reason,
      description: description.trim(),
      evidenceUrls: evidenceUrls
          .where((u) => u.trim().isNotEmpty)
          .map((u) => u.trim())
          .toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _disputeRepo.insert(record);

    // ── Pause the project ────────────────────────────────────────────────────
    await _projectRepo.updateStatus(project.id, ProjectStatus.disputed);

    return record;
  }

  // ── Admin: start review ────────────────────────────────────────────────────

  /// Admin marks the dispute as [DisputeStatus.underReview].
  Future<DisputeRecord> startReview(
    DisputeRecord dispute,
    String adminId,
  ) async {
    if (dispute.status != DisputeStatus.open) {
      throw Exception('Dispute is not in open state.');
    }
    final updated = dispute.copyWith(status: DisputeStatus.underReview);
    await _disputeRepo.update(updated);
    return updated;
  }

  // ── Admin: process resolution ──────────────────────────────────────────────

  /// Admin resolves the dispute. Adjusts escrow and closes the project.
  ///
  /// [clientRefundAmount] — only used for [DisputeResolution.partialSplit].
  ///   Must be ≥ 0 and ≤ remaining escrow balance.
  ///
  /// [adminNotes] — internal note attached to the dispute record.
  Future<DisputeResolutionResult> processResolution({
    required DisputeRecord dispute,
    required DisputeResolution resolution,
    required String adminId,
    String adminNotes = '',
    double? clientRefundAmount,
  }) async {
    if (dispute.status.isTerminal) {
      throw Exception('This dispute has already been resolved.');
    }

    // ── Load payment record ──────────────────────────────────────────────────
    final payment = await _paymentRepo.getForProject(dispute.projectId);

    // ── Execute payment adjustment ───────────────────────────────────────────
    PaymentRecord updatedPayment;
    PayoutRecord? disputePayout;
    double resolvedClientAmount = 0;
    double resolvedFreelancerAmount = 0;

    if (payment == null || !payment.isHeld) {
      // No active escrow — resolve without payment changes regardless.
      updatedPayment = payment ?? _emptyPaymentStub(dispute);
    } else {
      final remaining = payment.remainingHeld;

      switch (resolution) {
        // ── Full refund to client ────────────────────────────────────────────
        case DisputeResolution.fullRefundToClient:
          final svc = PaymentService(_paymentRepo);
          updatedPayment = await svc.refundRemainingBalance(payment);
          resolvedClientAmount = remaining;

        // ── Partial split ────────────────────────────────────────────────────
        case DisputeResolution.partialSplit:
          final refundAmt =
              (clientRefundAmount ?? 0).clamp(0.0, remaining);
          final releaseAmt = _round(remaining - refundAmt);
          resolvedClientAmount = refundAmt;
          resolvedFreelancerAmount = releaseAmt;

          var partial = payment;

          if (releaseAmt > 0.01) {
            final (p, payout) =
                await _createDisputePayout(partial, releaseAmt, dispute.id);
            partial = p;
            disputePayout = payout;
          }

          if (refundAmt > 0.01) {
            partial = partial.copyWith(
              refundedAmount: _round(partial.refundedAmount + refundAmt),
            );
          }

          // Final status
          final allDone = (partial.releasedAmount +
                      partial.refundedAmount -
                      partial.totalAmount)
                  .abs() <
              0.01;
          final hasReleases = partial.releasedAmount > 0;
          partial = partial.copyWith(
            status: allDone
                ? (hasReleases
                    ? PaymentStatus.partiallyRefunded
                    : PaymentStatus.refunded)
                : PaymentStatus.partiallyRefunded,
          );

          await _paymentRepo.update(partial);
          updatedPayment = partial;

        // ── Full release to freelancer ───────────────────────────────────────
        case DisputeResolution.fullReleaseToFreelancer:
          resolvedFreelancerAmount = remaining;
          final (p, payout) =
              await _createDisputePayout(payment, remaining, dispute.id);
          updatedPayment = p;
          disputePayout = payout;

        // ── No action ────────────────────────────────────────────────────────
        case DisputeResolution.noAction:
          updatedPayment = payment;
      }
    }

    // ── Close the project ────────────────────────────────────────────────────
    if (resolution == DisputeResolution.noAction) {
      // Dismiss dispute without financial consequences — restore project to
      // active so the parties can continue working.
      await _projectRepo.updateStatus(
          dispute.projectId, ProjectStatus.inProgress);
    } else {
      await _projectRepo.updateStatus(
          dispute.projectId, ProjectStatus.cancelled);
    }

    // ── Finalize dispute record ──────────────────────────────────────────────
    final resolved = dispute.copyWith(
      status: DisputeStatus.resolved,
      resolution: resolution,
      adminNotes: adminNotes.trim().isEmpty ? null : adminNotes.trim(),
      reviewedBy: adminId,
      reviewedAt: DateTime.now(),
      clientRefundAmount:
          resolvedClientAmount > 0 ? resolvedClientAmount : null,
      freelancerReleaseAmount:
          resolvedFreelancerAmount > 0 ? resolvedFreelancerAmount : null,
    );
    await _disputeRepo.update(resolved);

    return DisputeResolutionResult(
      dispute: resolved,
      payment: updatedPayment,
      disputePayout: disputePayout,
    );
  }

  // ── Admin: close (archive after resolved) ─────────────────────────────────

  Future<DisputeRecord> closeDispute(DisputeRecord dispute) async {
    if (dispute.status != DisputeStatus.resolved) {
      throw Exception(
          'Dispute must be resolved before it can be closed.');
    }
    final closed = dispute.copyWith(status: DisputeStatus.closed);
    await _disputeRepo.update(closed);
    return closed;
  }

  // ── Validation helpers (static) ────────────────────────────────────────────

  /// Returns an error string if the split amounts are invalid.
  static String? validatePartialSplit(
    double clientRefundAmount,
    double remainingHeld,
  ) {
    if (clientRefundAmount < 0) return 'Refund amount cannot be negative.';
    if (clientRefundAmount > remainingHeld) {
      return 'Refund amount (RM ${clientRefundAmount.toStringAsFixed(2)}) '
          'exceeds remaining escrow '
          '(RM ${remainingHeld.toStringAsFixed(2)}).';
    }
    return null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Creates a dispute-level payout (not tied to a specific milestone).
  Future<(PaymentRecord, PayoutRecord)> _createDisputePayout(
    PaymentRecord payment,
    double grossAmount,
    String disputeId,
  ) async {
    final calc = PaymentService.calculatePayout(
      grossAmount,
      platformFeePercent: payment.platformFeePercent,
    );

    final payout = PayoutRecord(
      id: _uuid.v4(),
      paymentId: payment.id,
      // Sentinel milestoneId indicating a dispute-resolution payout.
      milestoneId: 'dispute:$disputeId',
      projectId: payment.projectId,
      freelancerId: payment.freelancerId,
      grossAmount: calc.grossAmount,
      platformFee: calc.platformFee,
      netAmount: calc.netAmount,
      platformFeePercent: payment.platformFeePercent,
      payoutToken:
          'po_dispute_${_uuid.v4().replaceAll('-', '').substring(0, 16)}',
      status: PayoutStatus.processed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _paymentRepo.insertPayout(payout);

    final newReleased = _round(payment.releasedAmount + grossAmount);
    final allReleased =
        (newReleased - payment.totalAmount).abs() < 0.01;

    final updatedPayment = payment.copyWith(
      releasedAmount: newReleased,
      status: allReleased
          ? PaymentStatus.fullyReleased
          : PaymentStatus.partiallyReleased,
    );
    await _paymentRepo.update(updatedPayment);

    return (updatedPayment, payout);
  }

  /// Stub payment record used when no escrow exists (e.g. client skipped
  /// checkout in sandbox mode).
  PaymentRecord _emptyPaymentStub(DisputeRecord dispute) => PaymentRecord(
        id: _uuid.v4(),
        projectId: dispute.projectId,
        clientId: dispute.clientId,
        freelancerId: dispute.freelancerId,
        totalAmount: 0,
        platformFeePercent: PaymentService.defaultPlatformFeePercent,
        heldAmount: 0,
        releasedAmount: 0,
        refundedAmount: 0,
        status: PaymentStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static double _round(double v) => (v * 100).round() / 100;
}
