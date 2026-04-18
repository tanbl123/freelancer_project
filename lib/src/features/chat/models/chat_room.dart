import '../../../shared/enums/chat_room_type.dart';

/// A chat room between two or more users.
///
/// Room types:
/// - [ChatRoomType.direct]  — between any two users (general inquiry, pre-project)
/// - [ChatRoomType.project] — locked to a specific project's participants
/// - [ChatRoomType.appeal]  — admin ↔ appellant for an open appeal case
/// - [ChatRoomType.dispute] — admin ↔ both dispute parties
///
/// The room is identified by [id] in Supabase. [participantIds] contains the
/// UIDs of all users who can send/receive messages here. The last message
/// summary ([lastMessage], [lastMessageAt]) is updated on every new message
/// to power the room-list preview without fetching all messages.
class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.type,
    required this.participantIds,
    this.projectId,
    this.appealId,
    this.disputeId,
    this.lastMessage,
    this.lastSenderId,
    this.lastSenderName,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ChatRoomType type;

  /// All user IDs that are members of this room.
  final List<String> participantIds;

  /// Populated for [ChatRoomType.project] rooms.
  final String? projectId;

  /// Populated for [ChatRoomType.appeal] rooms.
  final String? appealId;

  /// Populated for [ChatRoomType.dispute] rooms.
  final String? disputeId;

  /// Snapshot of the last message text (for list preview).
  final String? lastMessage;

  /// UID of whoever sent the last message.
  final String? lastSenderId;

  /// Display name of the last sender (cached to avoid joins in the list view).
  final String? lastSenderName;

  /// Timestamp of the last message.
  final DateTime? lastMessageAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  /// The other participant's ID in a [ChatRoomType.direct] room.
  String otherParticipantId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => myId);

  bool hasParticipant(String uid) => participantIds.contains(uid);

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'type': type.name,
        'participant_ids': participantIds,
        'project_id': projectId,
        'appeal_id': appealId,
        'dispute_id': disputeId,
        'last_message': lastMessage,
        'last_sender_id': lastSenderId,
        'last_sender_name': lastSenderName,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullable(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    List<String> parseIds(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return ChatRoom(
      id: map['id'] as String,
      type: ChatRoomType.fromString(map['type'] as String? ?? 'direct'),
      participantIds: parseIds(map['participant_ids']),
      projectId: map['project_id'] as String?,
      appealId: map['appeal_id'] as String?,
      disputeId: map['dispute_id'] as String?,
      lastMessage: map['last_message'] as String?,
      lastSenderId: map['last_sender_id'] as String?,
      lastSenderName: map['last_sender_name'] as String?,
      lastMessageAt: parseNullable(map['last_message_at']),
      createdAt: parse(map['created_at']),
      updatedAt: parse(map['updated_at']),
    );
  }

  ChatRoom copyWith({
    String? lastMessage,
    String? lastSenderId,
    String? lastSenderName,
    DateTime? lastMessageAt,
    List<String>? participantIds,
  }) =>
      ChatRoom(
        id: id,
        type: type,
        participantIds: participantIds ?? this.participantIds,
        projectId: projectId,
        appealId: appealId,
        disputeId: disputeId,
        lastMessage: lastMessage ?? this.lastMessage,
        lastSenderId: lastSenderId ?? this.lastSenderId,
        lastSenderName: lastSenderName ?? this.lastSenderName,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
