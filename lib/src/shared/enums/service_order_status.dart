import 'package:flutter/material.dart';

enum ServiceOrderStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  convertedToProject,
  completed;

  static ServiceOrderStatus fromString(String v) =>
      ServiceOrderStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ServiceOrderStatus.pending,
      );

  String get displayName {
    switch (this) {
      case ServiceOrderStatus.pending:
        return 'Pending';
      case ServiceOrderStatus.accepted:
        return 'Accepted';
      case ServiceOrderStatus.rejected:
        return 'Rejected';
      case ServiceOrderStatus.cancelled:
        return 'Cancelled';
      case ServiceOrderStatus.convertedToProject:
        return 'Accepted';   // order was accepted → project was created
      case ServiceOrderStatus.completed:
        return 'Completed';
    }
  }

  Color get color {
    switch (this) {
      case ServiceOrderStatus.pending:
        return Colors.orange;
      case ServiceOrderStatus.accepted:
        return Colors.green;
      case ServiceOrderStatus.rejected:
        return Colors.red;
      case ServiceOrderStatus.cancelled:
        return Colors.grey;
      case ServiceOrderStatus.convertedToProject:
        return Colors.green;
      case ServiceOrderStatus.completed:
        return Colors.teal;
    }
  }

  /// Whether the order has reached a final state (no further transitions).
  bool get isTerminal =>
      this == ServiceOrderStatus.rejected ||
      this == ServiceOrderStatus.cancelled ||
      this == ServiceOrderStatus.convertedToProject ||
      this == ServiceOrderStatus.completed;
}
