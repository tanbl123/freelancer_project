import '../../../shared/enums/payment_status.dart';

/// Escrow record for an entire project's contract value.
///
/// Created when the client approves the milestone plan.
/// Tracks how much of the total is still held, how much has been
/// released to the freelancer via milestone payouts, and how much has
/// been refunded on cancellation.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.projectId,
    required this.clientId,
    required this.freelancerId,
    required this.totalAmount,
    required this.platformFeePercent,
    required this.heldAmount,
    required this.releasedAmount,
    required this.refundedAmount,
    this.stripePaymentIntentId,
    this.stripePaymentMethodId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String clientId;
  final String freelancerId;

  /// Full contract value agreed between client and freelancer.
  final double totalAmount;

  /// Platform fee percentage taken from each milestone payout (e.g. 10.0).
  final double platformFeePercent;

  /// Amount captured from the client's card and locked in escrow.
  final double heldAmount;

  /// Cumulative gross amount released to the freelancer (before fee).
  final double releasedAmount;

  /// Amount returned to the client due to cancellation.
  final double refundedAmount;

  /// Stripe PaymentIntent ID (server-side — available in production).
  final String? stripePaymentIntentId;

  /// Stripe PaymentMethod ID (card token from client).
  final String? stripePaymentMethodId;

  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  /// Funds still locked in escrow (not yet released or refunded).
  double get remainingHeld =>
      (heldAmount - releasedAmount - refundedAmount).clamp(0.0, heldAmount);

  /// Total platform fees collected so far on released milestones.
  double get totalPlatformFeesCollected =>
      releasedAmount * platformFeePercent / 100;

  /// Net amount the freelancer has actually received after platform fees.
  double get freelancerNetReceived =>
      releasedAmount - totalPlatformFeesCollected;

  /// Percentage of total contract value that has been released.
  double get releaseProgress =>
      totalAmount > 0 ? (releasedAmount / totalAmount).clamp(0.0, 1.0) : 0;

  bool get isPending => status == PaymentStatus.pending;
  bool get isHeld =>
      status == PaymentStatus.held ||
      status == PaymentStatus.partiallyReleased;

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'project_id': projectId,
        'client_id': clientId,
        'freelancer_id': freelancerId,
        'total_amount': totalAmount,
        'platform_fee_percent': platformFeePercent,
        'held_amount': heldAmount,
        'released_amount': releasedAmount,
        'refunded_amount': refundedAmount,
        'stripe_payment_intent_id': stripePaymentIntentId,
        'stripe_payment_method_id': stripePaymentMethodId,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) =>
        v is String ? (DateTime.tryParse(v) ?? DateTime.now()) : DateTime.now();

    return PaymentRecord(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      clientId: map['client_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      platformFeePercent:
          (map['platform_fee_percent'] as num? ?? 10.0).toDouble(),
      heldAmount: (map['held_amount'] as num? ?? 0).toDouble(),
      releasedAmount: (map['released_amount'] as num? ?? 0).toDouble(),
      refundedAmount: (map['refunded_amount'] as num? ?? 0).toDouble(),
      stripePaymentIntentId: map['stripe_payment_intent_id'] as String?,
      stripePaymentMethodId: map['stripe_payment_method_id'] as String?,
      status: PaymentStatus.fromString(
          map['status'] as String? ?? 'pending'),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  PaymentRecord copyWith({
    double? heldAmount,
    double? releasedAmount,
    double? refundedAmount,
    PaymentStatus? status,
    String? stripePaymentIntentId,
    String? stripePaymentMethodId,
  }) =>
      PaymentRecord(
        id: id,
        projectId: projectId,
        clientId: clientId,
        freelancerId: freelancerId,
        totalAmount: totalAmount,
        platformFeePercent: platformFeePercent,
        heldAmount: heldAmount ?? this.heldAmount,
        releasedAmount: releasedAmount ?? this.releasedAmount,
        refundedAmount: refundedAmount ?? this.refundedAmount,
        stripePaymentIntentId:
            stripePaymentIntentId ?? this.stripePaymentIntentId,
        stripePaymentMethodId:
            stripePaymentMethodId ?? this.stripePaymentMethodId,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
