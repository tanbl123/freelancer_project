import '../../../features/transactions/models/milestone_item.dart';
import '../../../features/transactions/models/project_item.dart';
import '../../../shared/enums/payment_status.dart';
import '../../../shared/enums/payout_status.dart';
import '../models/payment_record.dart';
import '../models/payout_record.dart';
import '../repositories/payment_repository.dart';

// ── Value object returned by payout calculations ───────────────────────────

/// Breakdown for a single milestone payout.
class PayoutCalculation {
  const PayoutCalculation({
    required this.grossAmount,
    required this.platformFeePercent,
    required this.platformFee,
    required this.netAmount,
  });

  /// Milestone payment amount before fee deduction.
  final double grossAmount;

  final double platformFeePercent;

  /// Platform fee retained: [grossAmount] × [platformFeePercent] ÷ 100.
  final double platformFee;

  /// Amount transferred to the freelancer: [grossAmount] − [platformFee].
  final double netAmount;

  @override
  String toString() =>
      'Gross RM ${grossAmount.toStringAsFixed(2)}  '
      '− Fee RM ${platformFee.toStringAsFixed(2)} (${platformFeePercent.toStringAsFixed(0)}%)  '
      '= Net RM ${netAmount.toStringAsFixed(2)}';
}

// ── Service ────────────────────────────────────────────────────────────────

/// Business-logic layer for the payment module.
///
/// Calculation methods are `static` so they can be used by the UI without
/// requiring a service instance (e.g. to show fee breakdowns on the
/// checkout screen before any DB interaction).
class PaymentService {
  const PaymentService(this._repo);
  final PaymentRepository _repo;

  /// Default platform fee taken from each milestone payout (percent).
  static const double defaultPlatformFeePercent = 10.0;

  // ── Pure calculations (no DB) ─────────────────────────────────────────────

  /// Calculate payout breakdown for a single milestone amount.
  ///
  /// Example:
  /// ```
  /// final calc = PaymentService.calculatePayout(500.00);
  /// // grossAmount: 500.00
  /// // platformFee:  50.00  (10 %)
  /// // netAmount:   450.00  freelancer receives
  /// ```
  static PayoutCalculation calculatePayout(
    double milestoneAmount, {
    double platformFeePercent = defaultPlatformFeePercent,
  }) {
    final fee = _round(milestoneAmount * platformFeePercent / 100);
    return PayoutCalculation(
      grossAmount: milestoneAmount,
      platformFeePercent: platformFeePercent,
      platformFee: fee,
      netAmount: _round(milestoneAmount - fee),
    );
  }

  /// Calculate payout breakdowns for all milestones in a plan.
  static List<PayoutCalculation> calculateAllPayouts(
    List<MilestoneItem> milestones, {
    double platformFeePercent = defaultPlatformFeePercent,
  }) =>
      milestones
          .map((m) => calculatePayout(m.paymentAmount,
              platformFeePercent: platformFeePercent))
          .toList();

  /// Total platform fees across all milestones.
  static double totalPlatformFees(
    List<MilestoneItem> milestones, {
    double platformFeePercent = defaultPlatformFeePercent,
  }) =>
      _round(milestones.fold(
          0.0, (s, m) => s + m.paymentAmount * platformFeePercent / 100));

  /// Total net amount the freelancer receives across all milestones.
  static double totalFreelancerNet(
    List<MilestoneItem> milestones, {
    double platformFeePercent = defaultPlatformFeePercent,
  }) =>
      _round(milestones.fold(
          0.0,
          (s, m) =>
              s + m.paymentAmount * (1 - platformFeePercent / 100)));

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Checks that the sum of milestone payment amounts matches the project
  /// budget within a RM 0.01 tolerance.
  static String? validateMilestoneTotal(
    List<MilestoneItem> milestones,
    ProjectItem project,
  ) {
    if (project.totalBudget == null || project.totalBudget! <= 0) {
      return 'Project has no budget set.';
    }
    final total =
        milestones.fold(0.0, (s, m) => s + m.paymentAmount);
    final budget = project.totalBudget!;
    if ((total - budget).abs() > 0.01) {
      return 'Milestone total (RM ${total.toStringAsFixed(2)}) does not match '
          'the project budget (RM ${budget.toStringAsFixed(2)}).';
    }
    return null;
  }

  /// Checks the payment record has enough remaining escrow for a payout.
  static String? validateSufficientFunds(
    PaymentRecord payment,
    double payoutAmount,
  ) {
    if (payment.remainingHeld < payoutAmount - 0.01) {
      return 'Insufficient escrow balance '
          '(held: RM ${payment.remainingHeld.toStringAsFixed(2)}, '
          'required: RM ${payoutAmount.toStringAsFixed(2)}).';
    }
    return null;
  }

  // ── Lifecycle operations ───────────────────────────────────────────────────

  /// Creates a [PaymentRecord] in [PaymentStatus.pending] state.
  ///
  /// Called when a client approves the milestone plan but before they have
  /// completed checkout.
  Future<PaymentRecord> createPendingPayment({
    required ProjectItem project,
    required String paymentId,
  }) async {
    final record = PaymentRecord(
      id: paymentId,
      projectId: project.id,
      clientId: project.clientId,
      freelancerId: project.freelancerId,
      totalAmount: project.totalBudget ?? 0,
      platformFeePercent: defaultPlatformFeePercent,
      heldAmount: 0,
      releasedAmount: 0,
      refundedAmount: 0,
      status: PaymentStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repo.insert(record);
    return record;
  }

  /// Transitions the payment from [PaymentStatus.pending] → [PaymentStatus.held]
  /// after a successful Stripe capture.
  ///
  /// In production the PaymentIntent is created server-side (Supabase Edge
  /// Function) before checkout and confirmed here. In sandbox mode the intent
  /// ID is simulated by [StripeService.simulatePaymentIntent].
  Future<PaymentRecord> holdPayment(
    PaymentRecord payment, {
    required String stripePaymentIntentId,
    required String stripePaymentMethodId,
  }) async {
    final updated = payment.copyWith(
      heldAmount: payment.totalAmount,
      status: PaymentStatus.held,
      stripePaymentIntentId: stripePaymentIntentId,
      stripePaymentMethodId: stripePaymentMethodId,
    );
    await _repo.update(updated);
    return updated;
  }

  /// Releases the payout for an approved milestone.
  ///
  /// 1. Validates sufficient escrow balance.
  /// 2. Creates a [PayoutRecord] for the milestone.
  /// 3. Updates [PaymentRecord.releasedAmount] and advances its status.
  ///
  /// Returns a tuple `(updatedPayment, createdPayout)`.
  /// Throws [Exception] when validation fails.
  Future<(PaymentRecord, PayoutRecord)> releaseMilestonePayout(
    PaymentRecord payment,
    MilestoneItem milestone,
    String payoutId,
  ) async {
    final fundsError =
        validateSufficientFunds(payment, milestone.paymentAmount);
    if (fundsError != null) throw Exception(fundsError);

    final calc = calculatePayout(
      milestone.paymentAmount,
      platformFeePercent: payment.platformFeePercent,
    );

    // Create payout record
    final payout = PayoutRecord(
      id: payoutId,
      paymentId: payment.id,
      milestoneId: milestone.id,
      projectId: payment.projectId,
      freelancerId: payment.freelancerId,
      grossAmount: calc.grossAmount,
      platformFee: calc.platformFee,
      netAmount: calc.netAmount,
      platformFeePercent: payment.platformFeePercent,
      payoutToken:
          'po_${payoutId.replaceAll('-', '').substring(0, 16)}',
      status: PayoutStatus.processed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repo.insertPayout(payout);

    // Advance payment record
    final newReleased =
        _round(payment.releasedAmount + milestone.paymentAmount);
    final allReleased =
        (newReleased - payment.totalAmount).abs() < 0.01;

    final updatedPayment = payment.copyWith(
      releasedAmount: newReleased,
      status: allReleased
          ? PaymentStatus.fullyReleased
          : PaymentStatus.partiallyReleased,
    );
    await _repo.update(updatedPayment);

    return (updatedPayment, payout);
  }

  /// Refunds all remaining escrow funds to the client.
  ///
  /// Called when a project is cancelled or when an admin resolves a dispute
  /// in the client's favour.
  ///
  /// Status:
  /// - No prior payouts → [PaymentStatus.refunded]
  /// - Some payouts already made → [PaymentStatus.partiallyRefunded]
  Future<PaymentRecord> refundRemainingBalance(
      PaymentRecord payment) async {
    final remaining = payment.remainingHeld;
    final hasPriorPayouts = payment.releasedAmount > 0;

    final updated = payment.copyWith(
      refundedAmount: _round(payment.refundedAmount + remaining),
      status: hasPriorPayouts
          ? PaymentStatus.partiallyRefunded
          : PaymentStatus.refunded,
    );
    await _repo.update(updated);
    return updated;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static double _round(double v) => (v * 100).round() / 100;
}
