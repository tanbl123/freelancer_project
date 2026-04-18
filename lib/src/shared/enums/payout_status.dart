import 'package:flutter/material.dart';

/// Status of a single milestone-level payout to the freelancer.
enum PayoutStatus {
  /// Payout queued; not yet executed.
  pending,

  /// Payout successfully processed and net amount sent to freelancer.
  processed,

  /// Payout attempt failed (e.g., transfer error).
  failed;

  // ── Factories ──────────────────────────────────────────────────────────────

  static PayoutStatus fromString(String v) => switch (v) {
        'pending'   => pending,
        'processed' => processed,
        'failed'    => failed,
        _           => pending,
      };

  // ── Display ────────────────────────────────────────────────────────────────

  String get displayName => switch (this) {
        PayoutStatus.pending   => 'Pending',
        PayoutStatus.processed => 'Processed',
        PayoutStatus.failed    => 'Failed',
      };

  Color get color => switch (this) {
        PayoutStatus.pending   => Colors.grey,
        PayoutStatus.processed => Colors.green,
        PayoutStatus.failed    => Colors.red,
      };
}
