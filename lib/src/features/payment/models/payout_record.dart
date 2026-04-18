import '../../../shared/enums/payout_status.dart';

/// Represents a single milestone-level payout to the freelancer.
///
/// Created when the client approves a submitted milestone deliverable.
/// The [grossAmount] comes from the project escrow; [platformFee] is
/// retained by the platform; [netAmount] is what the freelancer receives.
class PayoutRecord {
  const PayoutRecord({
    required this.id,
    required this.paymentId,
    required this.milestoneId,
    required this.projectId,
    required this.freelancerId,
    required this.grossAmount,
    required this.platformFee,
    required this.netAmount,
    required this.platformFeePercent,
    this.payoutToken,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Parent [PaymentRecord.id].
  final String paymentId;

  /// Milestone that triggered this payout.
  final String milestoneId;

  final String projectId;
  final String freelancerId;

  /// Milestone payment amount (totalBudget × milestone percentage ÷ 100).
  final double grossAmount;

  /// Platform fee deducted: [grossAmount] × [platformFeePercent] ÷ 100.
  final double platformFee;

  /// Amount transferred to the freelancer: [grossAmount] − [platformFee].
  final double netAmount;

  final double platformFeePercent;

  /// Reference token (simulated in sandbox; Stripe Transfer ID in production).
  final String? payoutToken;

  final PayoutStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'payment_id': paymentId,
        'milestone_id': milestoneId,
        'project_id': projectId,
        'freelancer_id': freelancerId,
        'gross_amount': grossAmount,
        'platform_fee': platformFee,
        'net_amount': netAmount,
        'platform_fee_percent': platformFeePercent,
        'payout_token': payoutToken,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory PayoutRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) =>
        v is String ? (DateTime.tryParse(v) ?? DateTime.now()) : DateTime.now();

    return PayoutRecord(
      id: map['id'] as String,
      paymentId: map['payment_id'] as String,
      milestoneId: map['milestone_id'] as String,
      projectId: map['project_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      grossAmount: (map['gross_amount'] as num).toDouble(),
      platformFee: (map['platform_fee'] as num).toDouble(),
      netAmount: (map['net_amount'] as num).toDouble(),
      platformFeePercent:
          (map['platform_fee_percent'] as num? ?? 10.0).toDouble(),
      payoutToken: map['payout_token'] as String?,
      status:
          PayoutStatus.fromString(map['status'] as String? ?? 'pending'),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }
}
