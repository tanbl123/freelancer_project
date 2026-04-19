import 'package:flutter/material.dart';

enum JobStatus {
  open,
  closed,
  cancelled,

  /// Soft-deleted — invisible in all UI lists; row kept in DB for auditing.
  deleted;

  static JobStatus fromString(String v) => JobStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => JobStatus.cancelled,
      );

  String get displayName {
    switch (this) {
      case JobStatus.open:
        return 'Open';
      case JobStatus.closed:
        return 'Closed';
      case JobStatus.cancelled:
        return 'Cancelled';
      case JobStatus.deleted:
        return 'Deleted';
    }
  }

  Color get color {
    switch (this) {
      case JobStatus.open:
        return Colors.green;
      case JobStatus.closed:
        return Colors.blueGrey;
      case JobStatus.cancelled:
        return Colors.red;
      case JobStatus.deleted:
        return Colors.grey;
    }
  }

  /// True only for posts that are still accepting applications.
  bool get isActive => this == JobStatus.open;
}
