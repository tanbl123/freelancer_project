import '../../../shared/enums/notification_type.dart';

/// A single in-app notification stored in the `in_app_notifications` table.
///
/// Notifications are user-scoped and can deep-link to a project, milestone,
/// or chat room. They are marked [isRead] when the user opens
/// [NotificationsScreen] or taps the individual item.
class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.linkedProjectId,
    this.linkedMilestoneId,
    this.linkedChatRoomId,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;

  /// Deep-link: navigate to the project detail page when tapped.
  final String? linkedProjectId;

  /// Optional fine-grained link to a specific milestone.
  final String? linkedMilestoneId;

  /// Deep-link: navigate to a chat room when tapped ([NotificationType.newChatMessage]).
  final String? linkedChatRoomId;

  /// False until the user reads or dismisses this notification.
  final bool isRead;

  final DateTime createdAt;

  // ── Supabase serialisation ─────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type.name,
        'linked_project_id': linkedProjectId,
        'linked_milestone_id': linkedMilestoneId,
        'linked_chat_room_id': linkedChatRoomId,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory InAppNotification.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return InAppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: NotificationType.fromString(map['type'] as String? ?? ''),
      linkedProjectId: map['linked_project_id'] as String?,
      linkedMilestoneId: map['linked_milestone_id'] as String?,
      linkedChatRoomId: map['linked_chat_room_id'] as String?,
      isRead: map['is_read'] == true || map['is_read'] == 1,
      createdAt: parse(map['created_at']),
    );
  }

  InAppNotification copyWith({bool? isRead}) => InAppNotification(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        linkedProjectId: linkedProjectId,
        linkedMilestoneId: linkedMilestoneId,
        linkedChatRoomId: linkedChatRoomId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
