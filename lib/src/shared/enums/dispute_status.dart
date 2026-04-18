import 'package:flutter/material.dart';

/// Lifecycle of a formal dispute record.
///
/// ```
/// open → underReview → resolved → closed
/// ```
/// - [open]        Dispute raised; payment releases paused; admin notified.
/// - [underReview] Admin has started reviewing evidence.
/// - [resolved]    Admin made a decision; payment adjusted.
/// - [closed]      Fully processed and archived.
enum DisputeStatus {
  open,
  underReview,
  resolved,
  closed;

  static DisputeStatus fromString(String v) => DisputeStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => DisputeStatus.open,
      );

  String get displayName => switch (this) {
        DisputeStatus.open        => 'Open',
        DisputeStatus.underReview => 'Under Review',
        DisputeStatus.resolved    => 'Resolved',
        DisputeStatus.closed      => 'Closed',
      };

  Color get color => switch (this) {
        DisputeStatus.open        => Colors.red,
        DisputeStatus.underReview => Colors.orange,
        DisputeStatus.resolved    => Colors.green,
        DisputeStatus.closed      => Colors.grey,
      };

  IconData get icon => switch (this) {
        DisputeStatus.open        => Icons.gavel,
        DisputeStatus.underReview => Icons.manage_search,
        DisputeStatus.resolved    => Icons.check_circle,
        DisputeStatus.closed      => Icons.archive_outlined,
      };

  bool get isActive => this == open || this == underReview;
  bool get isTerminal => this == resolved || this == closed;
}
