import 'package:flutter/material.dart';

/// Tracks the lifecycle of a project-level escrow payment.
///
/// ```
/// pending → held → partiallyReleased → fullyReleased
///                ↘ partiallyRefunded (cancelled mid-way)
///         ↘ refunded (cancelled before any payout)
/// ```
enum PaymentStatus {
  /// PaymentRecord created but client has not paid yet.
  pending,

  /// Full contract amount captured and locked in escrow.
  held,

  /// Some milestones paid out; remaining funds still held.
  partiallyReleased,

  /// All milestones paid out — escrow fully disbursed.
  fullyReleased,

  /// Project cancelled before any payout — full refund issued.
  refunded,

  /// Project cancelled after partial payouts — remainder refunded.
  partiallyRefunded;

  // ── Factories ──────────────────────────────────────────────────────────────

  static PaymentStatus fromString(String v) => switch (v) {
        'pending'            => pending,
        'held'               => held,
        'partiallyReleased'  => partiallyReleased,
        'fullyReleased'      => fullyReleased,
        'refunded'           => refunded,
        'partiallyRefunded'  => partiallyRefunded,
        _                    => pending,
      };

  // ── Display ────────────────────────────────────────────────────────────────

  String get displayName => switch (this) {
        PaymentStatus.pending           => 'Awaiting Payment',
        PaymentStatus.held              => 'Held in Escrow',
        PaymentStatus.partiallyReleased => 'Partially Released',
        PaymentStatus.fullyReleased     => 'Fully Released',
        PaymentStatus.refunded          => 'Refunded',
        PaymentStatus.partiallyRefunded => 'Partially Refunded',
      };

  Color get color => switch (this) {
        PaymentStatus.pending           => Colors.grey,
        PaymentStatus.held              => Colors.blue,
        PaymentStatus.partiallyReleased => Colors.orange,
        PaymentStatus.fullyReleased     => Colors.green,
        PaymentStatus.refunded          => Colors.red,
        PaymentStatus.partiallyRefunded => Colors.deepOrange,
      };

  IconData get icon => switch (this) {
        PaymentStatus.pending           => Icons.hourglass_empty,
        PaymentStatus.held              => Icons.lock,
        PaymentStatus.partiallyReleased => Icons.lock_open,
        PaymentStatus.fullyReleased     => Icons.check_circle,
        PaymentStatus.refunded          => Icons.undo,
        PaymentStatus.partiallyRefunded => Icons.undo,
      };

  /// True when funds are actively locked in escrow.
  bool get isActive =>
      this == PaymentStatus.held || this == PaymentStatus.partiallyReleased;

  /// True when the payment lifecycle has ended (no further releases expected).
  bool get isSettled =>
      this == PaymentStatus.fullyReleased ||
      this == PaymentStatus.refunded ||
      this == PaymentStatus.partiallyRefunded;
}
