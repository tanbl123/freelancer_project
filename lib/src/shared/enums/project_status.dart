import 'package:flutter/material.dart';

enum ProjectStatus {
  /// Project created but awaiting freelancer milestone plan + client approval.
  pendingStart,

  /// Plan approved, work is underway.
  inProgress,

  /// All milestones completed and client signed off with final signature.
  completed,

  /// Cancelled by either party before completion.
  cancelled,

  /// A formal dispute has been raised and is under review.
  disputed;

  static ProjectStatus fromString(String v) => switch (v) {
        'pendingStart' => pendingStart,
        'inProgress' => inProgress,
        'completed' => completed,
        'cancelled' => cancelled,
        'disputed' => disputed,
        _ => pendingStart,
      };

  String get displayName => switch (this) {
        ProjectStatus.pendingStart => 'Pending Start',
        ProjectStatus.inProgress => 'In Progress',
        ProjectStatus.completed => 'Completed',
        ProjectStatus.cancelled => 'Cancelled',
        ProjectStatus.disputed => 'Disputed',
      };

  Color get color => switch (this) {
        ProjectStatus.pendingStart => Colors.orange,
        ProjectStatus.inProgress => Colors.blue,
        ProjectStatus.completed => Colors.green,
        ProjectStatus.cancelled => Colors.grey,
        ProjectStatus.disputed => Colors.red,
      };
}
