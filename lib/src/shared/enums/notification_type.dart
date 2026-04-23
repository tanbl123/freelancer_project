import 'package:flutter/material.dart';

/// All in-app notification categories.
///
/// Used to determine icon, colour and deeplink behaviour in
/// [NotificationsScreen] and [MainShell] badge.
enum NotificationType {
  // ── Account / verification ─────────────────────────────────────────────────
  accountVerified,            // email confirmed → account is now active
  freelancerRequestApproved,  // admin approved the freelancer-role request
  freelancerRequestRejected,  // admin rejected the freelancer-role request

  // ── Overdue pipeline ───────────────────────────────────────────────────────
  overdueWarning,    // milestone approaching deadline
  overdueEnforced,   // auto-cancel + restrict triggered

  // ── Extension flow ─────────────────────────────────────────────────────────
  extensionRequested, // freelancer asked for more time → client notified
  extensionApproved,  // client approved extension → freelancer notified
  extensionDenied,    // client denied extension   → freelancer notified

  // ── Application / order ───────────────────────────────────────────────────
  applicationAccepted,  // freelancer's job application accepted by client
  applicationRejected,  // freelancer's job application rejected by client
  orderPlaced,          // client placed a service order → freelancer notified
  orderAccepted,        // freelancer accepted a service order → client notified
  orderCompleted,       // service order marked completed
  orderRejected,        // freelancer rejected the service order

  // ── Payment / escrow ──────────────────────────────────────────────────────
  paymentHeld,      // escrow funded — project can begin
  paymentReleased,  // milestone payout released to freelancer
  refundInitiated,  // client notified of escrow refund
  accountRestricted, // freelancer notified of account restriction

  // ── Milestone lifecycle ────────────────────────────────────────────────────
  milestoneSubmitted, // freelancer submitted → client notified
  milestoneApproved,  // client approved      → freelancer notified
  milestoneRejected,  // client rejected      → freelancer notified

  // ── Dispute lifecycle ──────────────────────────────────────────────────────
  disputeRaised,    // both parties notified when dispute is filed
  disputeResolved,  // both parties notified when admin resolves dispute

  // ── Review ────────────────────────────────────────────────────────────────
  reviewReceived,   // freelancer notified when a client leaves a review

  // ── Appeal lifecycle ──────────────────────────────────────────────────────
  appealSubmitted,  // restricted/deactivated user submitted an appeal → admins notified
  appealApproved,   // admin approved the appeal → user notified
  appealRejected,   // admin rejected the appeal → user notified

  // ── Chat ──────────────────────────────────────────────────────────────────
  newChatMessage;   // new message in any chat room

  static NotificationType fromString(String v) =>
      NotificationType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => NotificationType.overdueWarning,
      );

  String get displayName => switch (this) {
        NotificationType.accountVerified           => 'Account Verified',
        NotificationType.freelancerRequestApproved => 'Request Approved',
        NotificationType.freelancerRequestRejected => 'Request Rejected',
        NotificationType.overdueWarning            => 'Deadline Warning',
        NotificationType.overdueEnforced           => 'Project Auto-Cancelled',
        NotificationType.extensionRequested        => 'Extension Requested',
        NotificationType.extensionApproved         => 'Extension Approved',
        NotificationType.extensionDenied           => 'Extension Denied',
        NotificationType.applicationAccepted       => 'Application Accepted',
        NotificationType.applicationRejected       => 'Application Rejected',
        NotificationType.orderPlaced               => 'New Order',
        NotificationType.orderAccepted             => 'Order Accepted',
        NotificationType.orderCompleted            => 'Order Completed',
        NotificationType.orderRejected             => 'Order Rejected',
        NotificationType.paymentHeld               => 'Payment Held',
        NotificationType.paymentReleased           => 'Payment Released',
        NotificationType.refundInitiated           => 'Refund Initiated',
        NotificationType.accountRestricted         => 'Account Restricted',
        NotificationType.milestoneSubmitted        => 'Milestone Submitted',
        NotificationType.milestoneApproved         => 'Milestone Approved',
        NotificationType.milestoneRejected         => 'Milestone Rejected',
        NotificationType.disputeRaised             => 'Dispute Filed',
        NotificationType.disputeResolved           => 'Dispute Resolved',
        NotificationType.reviewReceived            => 'New Review',
        NotificationType.appealSubmitted           => 'New Appeal',
        NotificationType.appealApproved            => 'Appeal Approved',
        NotificationType.appealRejected            => 'Appeal Rejected',
        NotificationType.newChatMessage            => 'New Message',
      };

  IconData get icon => switch (this) {
        NotificationType.accountVerified           => Icons.verified_user,
        NotificationType.freelancerRequestApproved => Icons.check_circle,
        NotificationType.freelancerRequestRejected => Icons.cancel,
        NotificationType.overdueWarning            => Icons.warning_amber,
        NotificationType.overdueEnforced           => Icons.cancel,
        NotificationType.extensionRequested        => Icons.more_time,
        NotificationType.extensionApproved         => Icons.check_circle,
        NotificationType.extensionDenied           => Icons.do_not_disturb_on,
        NotificationType.applicationAccepted       => Icons.thumb_up,
        NotificationType.applicationRejected       => Icons.thumb_down,
        NotificationType.orderPlaced               => Icons.shopping_cart,
        NotificationType.orderAccepted             => Icons.handshake,
        NotificationType.orderCompleted            => Icons.task_alt,
        NotificationType.orderRejected             => Icons.remove_shopping_cart,
        NotificationType.paymentHeld               => Icons.lock,
        NotificationType.paymentReleased           => Icons.payments,
        NotificationType.refundInitiated           => Icons.currency_exchange,
        NotificationType.accountRestricted         => Icons.lock,
        NotificationType.milestoneSubmitted        => Icons.upload_file,
        NotificationType.milestoneApproved         => Icons.verified,
        NotificationType.milestoneRejected         => Icons.close,
        NotificationType.disputeRaised             => Icons.gavel,
        NotificationType.disputeResolved           => Icons.balance,
        NotificationType.reviewReceived            => Icons.star,
        NotificationType.appealSubmitted           => Icons.gavel,
        NotificationType.appealApproved            => Icons.check_circle,
        NotificationType.appealRejected            => Icons.cancel,
        NotificationType.newChatMessage            => Icons.chat_bubble,
      };

  Color get color => switch (this) {
        NotificationType.accountVerified           => Colors.teal,
        NotificationType.freelancerRequestApproved => Colors.green,
        NotificationType.freelancerRequestRejected => Colors.red,
        NotificationType.overdueWarning            => Colors.orange,
        NotificationType.overdueEnforced           => Colors.red,
        NotificationType.extensionRequested        => Colors.blue,
        NotificationType.extensionApproved         => Colors.green,
        NotificationType.extensionDenied           => Colors.red,
        NotificationType.applicationAccepted       => Colors.green,
        NotificationType.applicationRejected       => Colors.red,
        NotificationType.orderPlaced               => Colors.indigo,
        NotificationType.orderAccepted             => Colors.green,
        NotificationType.orderCompleted            => Colors.teal,
        NotificationType.orderRejected             => Colors.red,
        NotificationType.paymentHeld               => Colors.indigo,
        NotificationType.paymentReleased           => Colors.green,
        NotificationType.refundInitiated           => Colors.teal,
        NotificationType.accountRestricted         => Colors.red,
        NotificationType.milestoneSubmitted        => Colors.blue,
        NotificationType.milestoneApproved         => Colors.green,
        NotificationType.milestoneRejected         => Colors.red,
        NotificationType.disputeRaised             => Colors.deepOrange,
        NotificationType.disputeResolved           => Colors.indigo,
        NotificationType.reviewReceived            => Colors.amber,
        NotificationType.appealSubmitted           => Colors.deepOrange,
        NotificationType.appealApproved            => Colors.green,
        NotificationType.appealRejected            => Colors.red,
        NotificationType.newChatMessage            => Colors.blue,
      };
}
