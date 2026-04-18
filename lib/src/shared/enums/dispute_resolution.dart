/// Admin's decision on how to resolve the escrow funds of a dispute.
///
/// Used to drive the payment-adjustment logic in [DisputeService.processResolution].
enum DisputeResolution {
  /// All remaining escrow funds are returned to the client.
  /// Use when: freelancer failed to deliver or project cancelled unfairly.
  fullRefundToClient,

  /// Remaining escrow is split: client gets a refund, freelancer gets a partial
  /// release (platform fee deducted from freelancer's portion).
  /// Use when: partial work was completed or a compromise is appropriate.
  partialSplit,

  /// All remaining escrow is released to the freelancer (platform fee deducted).
  /// Use when: work was legitimately completed but client wrongly disputed.
  fullReleaseToFreelancer,

  /// No payment changes. Dispute is closed as informational or withdrawn.
  /// Use when: the dispute was raised in error or parties settled directly.
  noAction;

  static DisputeResolution fromString(String v) =>
      DisputeResolution.values.firstWhere(
        (e) => e.name == v,
        orElse: () => DisputeResolution.noAction,
      );

  String get displayName => switch (this) {
        DisputeResolution.fullRefundToClient    => 'Full Refund to Client',
        DisputeResolution.partialSplit          => 'Partial Split',
        DisputeResolution.fullReleaseToFreelancer =>
            'Full Release to Freelancer',
        DisputeResolution.noAction              => 'No Action',
      };

  String get description => switch (this) {
        DisputeResolution.fullRefundToClient =>
            'Return all remaining escrow to the client.',
        DisputeResolution.partialSplit =>
            'Split remaining escrow between client (refund) and freelancer (payout).',
        DisputeResolution.fullReleaseToFreelancer =>
            'Release all remaining escrow to the freelancer (10% platform fee applies).',
        DisputeResolution.noAction =>
            'Close the dispute without changing the escrow balance.',
      };
}
