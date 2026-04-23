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

  /// Human-readable reason shown in a snackbar when a blocked action is
  /// attempted.  Guides restricted/deactivated users to the appeal flow.
  String get blockedActionMessage {
    switch (this) {
      case AccountStatus.restricted:
        return 'Your account is restricted. Go to your profile and submit '
            'an appeal to restore full access.';
      case AccountStatus.deactivated:
        return 'Your account has been deactivated. Please submit an appeal '
            'via your profile to request reinstatement.';
      default:
        return 'Your account is not active.';
    }
  }

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
