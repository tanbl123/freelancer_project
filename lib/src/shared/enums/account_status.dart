import 'package:flutter/material.dart';

enum AccountStatus {
  pendingVerification,
  active,
  restricted,
  deactivated;

  static AccountStatus fromString(String v) => AccountStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => AccountStatus.pendingVerification,
      );

  /// Whether the user may authenticate and access the app.
  bool get canLogin =>
      this == AccountStatus.active || this == AccountStatus.restricted;

  /// Whether the user may create posts or apply for jobs.
  bool get canPost => this == AccountStatus.active;

  /// Display label shown in UI badges.
  String get displayName {
    switch (this) {
      case AccountStatus.pendingVerification:
        return 'Pending Verification';
      case AccountStatus.active:
        return 'Active';
      case AccountStatus.restricted:
        return 'Restricted';
      case AccountStatus.deactivated:
        return 'Deactivated';
    }
  }

  Color get color {
    switch (this) {
      case AccountStatus.pendingVerification:
        return Colors.orange;
      case AccountStatus.active:
        return Colors.green;
      case AccountStatus.restricted:
        return Colors.amber;
      case AccountStatus.deactivated:
        return Colors.red;
    }
  }
}
