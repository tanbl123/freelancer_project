import 'package:flutter/material.dart';

/// Lifecycle status of a user review.
///
/// | Status      | Meaning                                         |
/// |-------------|--------------------------------------------------|
/// | published   | Visible to everyone (default)                   |
/// | reported    | Flagged by at least one user; awaiting moderation|
/// | removed     | Removed by an admin; hidden from public views    |
enum ReviewStatus {
  published,
  reported,
  removed;

  static ReviewStatus fromString(String v) => ReviewStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ReviewStatus.published,
      );

  String get displayName {
    switch (this) {
      case ReviewStatus.published:
        return 'Published';
      case ReviewStatus.reported:
        return 'Reported';
      case ReviewStatus.removed:
        return 'Removed';
    }
  }

  Color get color {
    switch (this) {
      case ReviewStatus.published:
        return Colors.green;
      case ReviewStatus.reported:
        return Colors.orange;
      case ReviewStatus.removed:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case ReviewStatus.published:
        return Icons.check_circle_outline;
      case ReviewStatus.reported:
        return Icons.flag_outlined;
      case ReviewStatus.removed:
        return Icons.block_outlined;
    }
  }

  bool get isVisible => this == ReviewStatus.published;
}
