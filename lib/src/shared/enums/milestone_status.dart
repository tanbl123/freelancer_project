import 'package:flutter/material.dart';

enum MilestoneStatus {
  /// Freelancer has proposed this milestone; awaiting client plan approval.
  pendingApproval,

  /// Client approved the plan — this milestone is queued but not started.
  approved,

  /// This milestone is the current active one being worked on.
  inProgress,

  /// Freelancer submitted the deliverable; awaiting client review.
  submitted,

  /// Client approved the deliverable, signed, and payment was released.
  completed,

  /// Client rejected the submitted deliverable (can be revised).
  rejected;

  static MilestoneStatus fromString(String v) => switch (v) {
        'pendingApproval' => pendingApproval,
        'approved' => approved,
        'inProgress' => inProgress,
        'submitted' => submitted,
        'completed' => completed,
        'rejected' => rejected,
        // ── Legacy value migration ──────────────────────────────────────────
        'draft' => inProgress,
        'locked' => completed,
        _ => pendingApproval,
      };

  String get displayName => switch (this) {
        MilestoneStatus.pendingApproval => 'Pending Approval',
        MilestoneStatus.approved => 'Approved',
        MilestoneStatus.inProgress => 'In Progress',
        MilestoneStatus.submitted => 'Submitted',
        MilestoneStatus.completed => 'Completed',
        MilestoneStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        MilestoneStatus.pendingApproval => Colors.orange,
        MilestoneStatus.approved => Colors.teal,
        MilestoneStatus.inProgress => Colors.blue,
        MilestoneStatus.submitted => Colors.purple,
        MilestoneStatus.completed => Colors.green,
        MilestoneStatus.rejected => Colors.red,
      };

  bool get isTerminal =>
      this == MilestoneStatus.completed || this == MilestoneStatus.rejected;
}
