import 'package:flutter/material.dart';

enum AppealStatus {
  open,
  underReview,
  approved,
  rejected;

  /// Parses a DB value into [AppealStatus].
  ///
  /// The DB stores `'under_review'` (snake_case) for [underReview].
  /// The normaliser strips underscores and lowercases before matching so
  /// both `'under_review'` and `'underReview'` resolve correctly.
  /// All other values are stored as their camelCase [name].
  static AppealStatus fromString(String v) {
    final normalised = v.replaceAll('_', '').toLowerCase();
    return AppealStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == normalised,
      orElse: () => AppealStatus.open,
    );
  }

  /// The value written to the database.
  ///
  /// **Always use [dbValue] when persisting — never [name].**
  /// [underReview] is stored as `'under_review'` to match the SQL CHECK
  /// constraint; all other values are stored as their plain [name].
  String get dbValue {
    switch (this) {
      case AppealStatus.underReview:
        return 'under_review';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case AppealStatus.open:
        return 'Open';
      case AppealStatus.underReview:
        return 'Under Review';
      case AppealStatus.approved:
        return 'Approved';
      case AppealStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case AppealStatus.open:
        return Colors.orange;
      case AppealStatus.underReview:
        return Colors.blue;
      case AppealStatus.approved:
        return Colors.green;
      case AppealStatus.rejected:
        return Colors.red;
    }
  }
}
