import 'package:flutter/material.dart';

enum RequestStatus {
  pending,
  approved,
  rejected;

  static RequestStatus fromString(String v) => RequestStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => RequestStatus.pending,
      );

  String get displayName {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.approved:
        return Colors.green;
      case RequestStatus.rejected:
        return Colors.red;
    }
  }
}
