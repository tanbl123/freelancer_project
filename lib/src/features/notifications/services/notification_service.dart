import 'package:uuid/uuid.dart';

import '../../../shared/enums/notification_type.dart';
import '../models/in_app_notification.dart';
import '../repositories/notification_repository.dart';

/// Business-logic layer for in-app notifications.
///
/// Factory static methods build the correct [InAppNotification] for each
/// system event so callers don't need to construct the strings themselves.
class NotificationService {
  const NotificationService(this._repo);
  final NotificationRepository _repo;

  static const _uuid = Uuid();

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> send(InAppNotification notification) =>
      _repo.insert(notification);

  Future<List<InAppNotification>> loadForUser(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) =>
      _repo.getForUser(userId, limit: limit, offset: offset);

  Future<int> unreadCount(String userId) => _repo.unreadCount(userId);

  Future<void> markRead(String notificationId) =>
      _repo.markRead(notificationId);

  Future<void> markAllRead(String userId) => _repo.markAllRead(userId);

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Overdue warning sent to BOTH client and freelancer.
  static InAppNotification makeOverdueWarning({
    required String userId,
    required String milestoneTitle,
    required int daysRemaining,
    required String projectId,
    required String milestoneId,
    bool isFreelancer = true,
  }) {
    final urgency = daysRemaining > 1
        ? '$daysRemaining days'
        : daysRemaining == 1
            ? '1 day'
            : 'today';

    final title = daysRemaining > 0
        ? '⚠️ Deadline in $urgency'
        : '🔴 Deadline has passed';

    final body = isFreelancer
        ? '"$milestoneTitle" is ${daysRemaining > 0 ? 'due in $urgency' : 'overdue'}. '
          'Submit your deliverable or request an extension now.'
        : '"$milestoneTitle" is ${daysRemaining > 0 ? 'due in $urgency' : 'overdue'}. '
          'You will be notified if the freelancer fails to deliver.';

    return InAppNotification(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      body: body,
      type: NotificationType.overdueWarning,
      linkedProjectId: projectId,
      linkedMilestoneId: milestoneId,
      createdAt: DateTime.now(),
    );
  }

  /// Final-warning notification (deadline passed, enforcement pending).
  static InAppNotification makeFinalWarning({
    required String userId,
    required String milestoneTitle,
    required String projectTitle,
    required bool isFreelancer,
    required String projectId,
    required String milestoneId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: '🔴 Final warning — ${isFreelancer ? 'submit now' : 'deadline passed'}',
        body: isFreelancer
            ? '"$milestoneTitle" deadline has passed. You have 24 hours to submit '
              'before "$projectTitle" is automatically cancelled and your account restricted.'
            : '"$milestoneTitle" deadline has passed. If the freelancer does not '
              'deliver within 24 hours the project will be cancelled and escrow refunded.',
        type: NotificationType.overdueWarning,
        linkedProjectId: projectId,
        linkedMilestoneId: milestoneId,
        createdAt: DateTime.now(),
      );

  /// Enforcement notification sent after auto-cancel fires.
  static InAppNotification makeEnforcement({
    required String userId,
    required String milestoneTitle,
    required String projectTitle,
    required bool isFreelancer,
    required String projectId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: isFreelancer
            ? '🚫 Project cancelled — account restricted'
            : '✅ Project cancelled — refund initiated',
        body: isFreelancer
            ? 'You did not deliver "$milestoneTitle" in "$projectTitle". '
              'Your account has been restricted. '
              'Go to your profile to submit an appeal.'
            : '"$milestoneTitle" was not delivered. "$projectTitle" has been '
              'cancelled and your remaining escrow balance will be refunded.',
        type: isFreelancer
            ? NotificationType.accountRestricted
            : NotificationType.refundInitiated,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  /// Sent to the client when the freelancer requests an extension.
  static InAppNotification makeExtensionRequested({
    required String clientId,
    required String milestoneTitle,
    required int days,
    required String projectId,
    required String milestoneId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: clientId,
        title: '⏱ Extension requested',
        body: 'The freelancer is requesting $days extra '
            'day${days == 1 ? '' : 's'} for "$milestoneTitle". '
            'Approve or deny in the project detail page.',
        type: NotificationType.extensionRequested,
        linkedProjectId: projectId,
        linkedMilestoneId: milestoneId,
        createdAt: DateTime.now(),
      );

  /// Sent to the freelancer when the client approves an extension.
  static InAppNotification makeExtensionApproved({
    required String freelancerId,
    required String milestoneTitle,
    required int days,
    required String projectId,
    required String milestoneId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '✅ Extension approved',
        body: 'Your $days-day extension for "$milestoneTitle" has been approved. '
            'New deadline set.',
        type: NotificationType.extensionApproved,
        linkedProjectId: projectId,
        linkedMilestoneId: milestoneId,
        createdAt: DateTime.now(),
      );

  /// Sent to the freelancer when the client denies an extension.
  static InAppNotification makeExtensionDenied({
    required String freelancerId,
    required String milestoneTitle,
    required String projectId,
    required String milestoneId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '❌ Extension denied',
        body: 'Your extension request for "$milestoneTitle" was denied. '
            'Please submit your deliverable by the original deadline.',
        type: NotificationType.extensionDenied,
        linkedProjectId: projectId,
        linkedMilestoneId: milestoneId,
        createdAt: DateTime.now(),
      );

  /// Sent to the freelancer when the client approves the plan AND payment is held.
  /// Signals "you can now start your work".
  static InAppNotification makePlanApproved({
    required String freelancerId,
    required String projectTitle,
    required double heldAmount,
    required String projectId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '🎉 Plan approved — start your work!',
        body: 'The client has approved your plan for "$projectTitle" and '
            'secured RM ${heldAmount.toStringAsFixed(2)} in escrow. '
            'You can now begin working on the first milestone.',
        type: NotificationType.paymentHeld,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  /// Sent to the client when the freelancer proposes a milestone plan.
  static InAppNotification makePlanProposed({
    required String clientId,
    required String projectTitle,
    required int milestoneCount,
    required String projectId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: clientId,
        title: '📋 Milestone plan ready for review',
        body: 'The freelancer has proposed a $milestoneCount-milestone plan '
            'for "$projectTitle". Review and pay to get started.',
        type: NotificationType.milestoneSubmitted,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  /// Sent to the client when the freelancer submits a deliverable.
  static InAppNotification makeMilestoneSubmitted({
    required String clientId,
    required String milestoneTitle,
    required String projectId,
    required String milestoneId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: clientId,
        title: '📤 Deliverable submitted',
        body: 'The freelancer has submitted work for "$milestoneTitle". '
            'Review and approve or reject.',
        type: NotificationType.milestoneSubmitted,
        linkedProjectId: projectId,
        linkedMilestoneId: milestoneId,
        createdAt: DateTime.now(),
      );

  /// Sent to the freelancer when the client approves a milestone.
  static InAppNotification makeMilestoneApproved({
    required String freelancerId,
    required String milestoneTitle,
    required double netAmount,
    required String projectId,
    required String milestoneId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '✅ Milestone approved',
        body: '"$milestoneTitle" has been approved. '
            'RM ${netAmount.toStringAsFixed(2)} has been released to you.',
        type: NotificationType.milestoneApproved,
        linkedProjectId: projectId,
        linkedMilestoneId: milestoneId,
        createdAt: DateTime.now(),
      );

  /// Sent to the freelancer when the client rejects a milestone.
  static InAppNotification makeMilestoneRejected({
    required String freelancerId,
    required String milestoneTitle,
    required String reason,
    required String projectId,
    required String milestoneId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '❌ Milestone rejected',
        body: '"$milestoneTitle" was rejected: $reason. '
            'Please revise and resubmit.',
        type: NotificationType.milestoneRejected,
        linkedProjectId: projectId,
        linkedMilestoneId: milestoneId,
        createdAt: DateTime.now(),
      );

  // ── Application & order factories ─────────────────────────────────────────

  /// Sent to the CLIENT when a freelancer submits a new application on their job.
  static InAppNotification makeNewApplicant({
    required String clientId,
    required String jobTitle,
    required String freelancerName,
    required String jobId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: clientId,
        title: '📩 New applicant on "$jobTitle"',
        body: '$freelancerName has applied to your job posting. '
            'Review their application and proposal.',
        type: NotificationType.applicationAccepted, // closest semantic match
        linkedProjectId: jobId,
        createdAt: DateTime.now(),
      );

  /// Sent to the FREELANCER when a client places a new service order.
  static InAppNotification makeNewServiceOrder({
    required String freelancerId,
    required String serviceTitle,
    required String clientName,
    required String orderId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '🛒 New order: "$serviceTitle"',
        body: '$clientName has placed an order for your service. '
            'Accept to create a project, or reject if you cannot take it.',
        type: NotificationType.orderPlaced,
        // linkedProjectId is intentionally null here — no project exists yet.
        // The project is only created when the freelancer accepts the order.
        createdAt: DateTime.now(),
      );

  /// Sent to the CLIENT when a freelancer accepts their service order.
  static InAppNotification makeOrderAccepted({
    required String clientId,
    required String serviceTitle,
    required String freelancerName,
    required String projectId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: clientId,
        title: '✅ Order accepted — "$serviceTitle"',
        body: '$freelancerName has accepted your order and created a project. '
            'Wait for the milestone plan, then review and pay to get started.',
        type: NotificationType.orderAccepted,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  /// Sent to the CLIENT when a freelancer rejects their service order.
  static InAppNotification makeOrderRejected({
    required String clientId,
    required String serviceTitle,
    required String freelancerName,
    required String reason,
    required String orderId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: clientId,
        title: '❌ Order rejected — "$serviceTitle"',
        body: '$freelancerName could not accept your order. '
            'Reason: $reason. You may order from another freelancer.',
        type: NotificationType.orderRejected,
        // No project exists for a rejected order — don't store the orderId
        // in linked_project_id as it would violate the projects FK constraint.
        createdAt: DateTime.now(),
      );

  // ── Dispute factories ──────────────────────────────────────────────────────

  /// Sent to BOTH parties when a dispute is raised.
  static InAppNotification makeDisputeRaised({
    required String userId,
    required String projectTitle,
    required String projectId,
    required bool isRaiser,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: '⚖️ Dispute filed on "$projectTitle"',
        body: isRaiser
            ? 'Your dispute has been submitted. An admin will review it and '
              'contact you with next steps. Payment releases are paused.'
            : 'A dispute has been raised on "$projectTitle". '
              'Payment releases are paused until an admin resolves it.',
        type: NotificationType.disputeRaised,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  /// Sent to BOTH parties when admin resolves the dispute.
  static InAppNotification makeDisputeResolved({
    required String userId,
    required String projectTitle,
    required String resolutionLabel,
    required String projectId,
    required bool isClient,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: '✅ Dispute resolved — "$projectTitle"',
        body: isClient
            ? 'The admin resolved the dispute: $resolutionLabel. '
              'Check your payment status for refund details.'
            : 'The admin resolved the dispute: $resolutionLabel. '
              'Check your payout records for release details.',
        type: NotificationType.disputeResolved,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  // ── Account & verification ─────────────────────────────────────────────────

  static InAppNotification makeAccountVerified({
    required String userId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: '✅ Email verified',
        body: 'Your email address has been verified. '
            'Your account is now fully active.',
        type: NotificationType.accountVerified,
        createdAt: DateTime.now(),
      );

  static InAppNotification makeFreelancerRequestApproved({
    required String userId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: '🎉 Freelancer request approved',
        body: 'Congratulations! Your request to become a freelancer '
            'has been approved. You can now apply to jobs and offer services.',
        type: NotificationType.freelancerRequestApproved,
        createdAt: DateTime.now(),
      );

  static InAppNotification makeFreelancerRequestRejected({
    required String userId,
    String? note,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: userId,
        title: '❌ Freelancer request rejected',
        body: note != null && note.isNotEmpty
            ? 'Your freelancer request was rejected: $note'
            : 'Your request to become a freelancer was not approved at this time.',
        type: NotificationType.freelancerRequestRejected,
        createdAt: DateTime.now(),
      );

  // ── Application / order ────────────────────────────────────────────────────

  static InAppNotification makeApplicationAccepted({
    required String freelancerId,
    required String jobTitle,
    required String projectId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '🎉 Application accepted',
        body: 'Your application for "$jobTitle" was accepted! '
            'The client will reach out with next steps.',
        type: NotificationType.applicationAccepted,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  static InAppNotification makeApplicationRejected({
    required String freelancerId,
    required String jobTitle,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: 'Application not selected',
        body: 'Your application for "$jobTitle" was not selected this time. '
            'Keep applying — there are more opportunities!',
        type: NotificationType.applicationRejected,
        createdAt: DateTime.now(),
      );

  static InAppNotification makeOrderCompleted({
    required String clientId,
    required String serviceName,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: clientId,
        title: '🎁 Order completed',
        body: '"$serviceName" has been marked as completed. '
            'Please leave a review for the freelancer.',
        type: NotificationType.orderCompleted,
        createdAt: DateTime.now(),
      );

  // ── Payment ────────────────────────────────────────────────────────────────

  static InAppNotification makePaymentHeld({
    required String freelancerId,
    required String projectTitle,
    required double amount,
    required String projectId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '💰 Payment held in escrow',
        body: 'RM ${amount.toStringAsFixed(2)} has been placed in escrow '
            'for "$projectTitle". You can now begin work.',
        type: NotificationType.paymentHeld,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  static InAppNotification makePaymentReleased({
    required String freelancerId,
    required String milestoneTitle,
    required double netAmount,
    required String projectId,
    required String milestoneId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '💳 Payment released',
        body: 'RM ${netAmount.toStringAsFixed(2)} has been released '
            'for completing "$milestoneTitle".',
        type: NotificationType.paymentReleased,
        linkedProjectId: projectId,
        linkedMilestoneId: milestoneId,
        createdAt: DateTime.now(),
      );

  // ── Review ─────────────────────────────────────────────────────────────────

  static InAppNotification makeReviewReceived({
    required String freelancerId,
    required String clientName,
    required int stars,
    required String projectId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: freelancerId,
        title: '⭐ New review received',
        body: '$clientName left you a $stars-star review. '
            'Check your profile to see what they said.',
        type: NotificationType.reviewReceived,
        linkedProjectId: projectId,
        createdAt: DateTime.now(),
      );

  // ── Chat ───────────────────────────────────────────────────────────────────

  static InAppNotification makeNewChatMessage({
    required String recipientId,
    required String senderName,
    required String messagePreview,
    required String chatRoomId,
    String? linkedProjectId,
  }) =>
      InAppNotification(
        id: _uuid.v4(),
        userId: recipientId,
        title: '💬 $senderName',
        body: messagePreview,
        type: NotificationType.newChatMessage,
        linkedProjectId: linkedProjectId,
        linkedChatRoomId: chatRoomId,
        createdAt: DateTime.now(),
      );
}
