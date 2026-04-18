import '../../../shared/enums/message_type.dart';

/// A single message in a [ChatRoom].
///
/// Messages are immutable once created. [messageType] distinguishes user text
/// from automated system messages (e.g. "Project started", "Dispute raised").
///
/// [senderName] is cached at write-time so the chat UI can render names
/// without joining to the profiles table on every read.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.messageType = MessageType.text,
    required this.createdAt,
  });

  final String id;
  final String roomId;

  /// UID of the sender.  For [MessageType.system] messages this is the empty
  /// string '' (no real sender).
  final String senderId;

  /// Cached display name of the sender.
  final String senderName;

  final String content;
  final MessageType messageType;
  final DateTime createdAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  bool get isSystem => messageType == MessageType.system;
  bool isMine(String myId) => senderId == myId;

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'message_type': messageType.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return ChatMessage(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      senderId: map['sender_id'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? 'Unknown',
      content: map['content'] as String? ?? '',
      messageType: MessageType.fromString(
          map['message_type'] as String? ?? 'text'),
      createdAt: parse(map['created_at']),
    );
  }
}
