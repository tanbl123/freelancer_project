/// The triggering reason for a dispute.
///
/// Maps directly to the `reason` column in `dispute_records`.
enum DisputeReason {
  /// Client submitted milestone but client hasn't approved or rejected it.
  milestoneNotApproved,

  /// Freelancer missed their milestone deadline without submitting work.
  projectOverdue,

  /// One party cancelled but the other disagrees with the cancellation.
  cancelledWithDisagreement,

  /// Work delivered does not meet the agreed requirements or quality standard.
  qualityIssue,

  /// Payment was not released despite milestone being completed correctly.
  paymentIssue,

  /// Any reason that doesn't fit the categories above.
  other;

  static DisputeReason fromString(String v) => DisputeReason.values.firstWhere(
        (e) => e.name == v,
        orElse: () => DisputeReason.other,
      );

  String get displayName => switch (this) {
        DisputeReason.milestoneNotApproved    => 'Milestone Not Approved',
        DisputeReason.projectOverdue          => 'Project Overdue',
        DisputeReason.cancelledWithDisagreement =>
            'Disputed Cancellation',
        DisputeReason.qualityIssue            => 'Quality Issue',
        DisputeReason.paymentIssue            => 'Payment Not Released',
        DisputeReason.other                   => 'Other',
      };

  String get description => switch (this) {
        DisputeReason.milestoneNotApproved =>
            'A milestone was submitted but the client has not approved or rejected it.',
        DisputeReason.projectOverdue =>
            'The freelancer missed the agreed deadline without submitting work.',
        DisputeReason.cancelledWithDisagreement =>
            'The project was cancelled but one party disagrees with the decision.',
        DisputeReason.qualityIssue =>
            'The delivered work does not meet the agreed requirements or quality.',
        DisputeReason.paymentIssue =>
            'Payment has not been released despite work being completed.',
        DisputeReason.other => 'Another reason not covered by the categories above.',
      };
}
