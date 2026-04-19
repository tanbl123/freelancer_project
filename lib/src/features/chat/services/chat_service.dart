import 'package:uuid/uuid.dart';

import '../../../shared/enums/account_status.dart';
import '../../../shared/enums/chat_room_type.dart';
import '../../../shared/enums/message_type.dart';
import '../../disputes/models/dispute_record.dart';
import '../../profile/models/profile_user.dart';
import '../../transactions/models/project_item.dart';
import '../../user/models/appeal.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../repositories/chat_repository.dart';

/// Business-logic layer for the chat system.
///
/// ## Permission model
///
/// | Room type | Who can join / message          |
/// |-----------|----------------------------------|
/// | direct    | The two designated participants |
/// | project   | Project client + freelancer      |
/// | appeal    | Appellant + any admin            |
/// | dispute   | Client + freelancer + any admin  |
///
/// Restricted/deactivated users may still message in [ChatRoomType.appeal] and
/// [ChatRoomType.dispute] rooms tied to unresolved cases so they can seek help.
class ChatService {
  const ChatService(this._repo);
  final ChatRepository _repo;

  static const _uuid = Uuid();

  // ── Room access ────────────────────────────────────────────────────────────

  /// Whether [user] is permitted to send messages in [room].
  bool canMessage(ProfileUser user, ChatRoom room) {
    // Must be a participant
    if (!room.hasParticipant(user.uid)) return false;

    // Fully deactivated accounts cannot message anywhere
    if (user.accountStatus == AccountStatus.deactivated) return false;

    // Restricted users can only message in appeal/dispute rooms
    if (user.accountStatus == AccountStatus.restricted) {
      return room.type == ChatRoomType.appeal ||
          room.type == ChatRoomType.dispute;
    }

    return true;
  }

  /// Whether [user] is permitted to view (open) [room].
  bool canView(ProfileUser user, ChatRoom room) {
    if (!room.hasParticipant(user.uid)) return false;
    if (user.accountStatus == AccountStatus.deactivated) return false;

    // Restricted users can view appeal/dispute rooms
    if (user.accountStatus == AccountStatus.restricted) {
      return room.type == ChatRoomType.appeal ||
          room.type == ChatRoomType.dispute;
    }
    return true;
  }

  // ── Room creation / retrieval ──────────────────────────────────────────────

  /// Get or create a direct chat room between [userId1] and [userId2].
  Future<ChatRoom> getOrCreateDirectRoom(
    String userId1,
    String userId2,
  ) async {
    final existing = await _repo.getDirectRoom(userId1, userId2);
    if (existing != null) return existing;

    return _repo.insert(ChatRoom(
      id: _uuid.v4(),
      type: ChatRoomType.direct,
      participantIds: [userId1, userId2],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  /// Get or create the project-scoped chat room.
  Future<ChatRoom> getOrCreateProjectRoom(ProjectItem project) async {
    final existing = await _repo.getProjectRoom(project.id);
    if (existing != null) return existing;

    final room = await _repo.insert(ChatRoom(
      id: _uuid.v4(),
      type: ChatRoomType.project,
      participantIds: [project.clientId, project.freelancerId],
      projectId: project.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    // Drop a system message so the conversation has a clear starting point
    await _sendSystem(
      room.id,
      '🚀 Project chat opened. Keep all project communication here.',
    );

    return room;
  }

  /// Get or create the appeal chat room.
  Future<ChatRoom> getOrCreateAppealRoom(
    Appeal appeal,
    List<String> adminIds,
  ) async {
    final existing = await _repo.getAppealRoom(appeal.id);
    if (existing != null) return existing;

    final participants = [appeal.appellantId, ...adminIds];
    final room = await _repo.insert(ChatRoom(
      id: _uuid.v4(),
      type: ChatRoomType.appeal,
      participantIds: participants,
      appealId: appeal.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    await _sendSystem(
      room.id,
      '📩 Appeal support chat opened. An admin will review your case.',
    );

    return room;
  }

  /// Get or create the dispute chat room.
  Future<ChatRoom> getOrCreateDisputeRoom(
    DisputeRecord dispute,
    List<String> adminIds,
  ) async {
    final existing = await _repo.getDisputeRoom(dispute.id);
    if (existing != null) return existing;

    final participants = [
      dispute.clientId,
      dispute.freelancerId,
      ...adminIds,
    ];
    final room = await _repo.insert(ChatRoom(
      id: _uuid.v4(),
      type: ChatRoomType.dispute,
      participantIds: participants,
      disputeId: dispute.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    await _sendSystem(
      room.id,
      '⚖️ Dispute chat opened. Payment releases are paused. '
      'An admin will mediate.',
    );

    return room;
  }

  // ── Messaging ──────────────────────────────────────────────────────────────

  /// Send a user text message.
  ///
  /// Throws if [sender] does not have permission to message in [room].
  Future<ChatMessage> sendMessage({
    required ChatRoom room,
    required ProfileUser sender,
    required String content,
  }) async {
    if (!canMessage(sender, room)) {
      throw Exception(
          'You do not have permission to send messages in this chat.');
    }
    if (content.trim().isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    final msg = await _repo.insertMessage(ChatMessage(
      id: _uuid.v4(),
      roomId: room.id,
      senderId: sender.uid,
      senderName: sender.displayName,
      content: content.trim(),
      createdAt: DateTime.now(),
    ));

    // Update room preview (fire-and-forget — read-your-writes is fine here)
    await _repo.update(room.copyWith(
      lastMessage: _truncate(content.trim()),
      lastSenderId: sender.uid,
      lastSenderName: sender.displayName,
      lastMessageAt: msg.createdAt,
    ));

    return msg;
  }

  /// Load [limit] messages for [roomId], oldest-first.
  Future<List<ChatMessage>> loadMessages(
    String roomId, {
    int limit = 50,
    int offset = 0,
  }) =>
      _repo.getMessages(roomId, limit: limit, offset: offset);

  /// Mark all messages in [room] as read for [userId].
  Future<void> markRead(String roomId, String userId) =>
      _repo.markRead(roomId, userId);

  // ── Unread calculation ─────────────────────────────────────────────────────

  /// Counts rooms that have a message newer than the user's last-read time.
  ///
  /// Returns a map of [roomId] → unread (true/false) so the UI can badge
  /// individual rooms.
  Future<Map<String, bool>> unreadRooms(
    String userId,
    List<ChatRoom> rooms,
  ) async {
    final reads = await _repo.getReadTimestamps(userId);
    final Map<String, bool> result = {};
    for (final room in rooms) {
      if (room.lastMessageAt == null) {
        result[room.id] = false;
        continue;
      }
      final lastRead = reads[room.id];
      if (lastRead == null) {
        // Never opened → unread if there is at least one message
        result[room.id] = room.lastMessage != null;
      } else {
        // Normalise both to UTC before comparing to avoid local-clock drift
        final msgTime = room.lastMessageAt!.toUtc();
        final readTime = lastRead.toUtc();
        result[room.id] = msgTime.isAfter(readTime);
      }
    }
    return result;
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  /// Supabase Realtime stream of raw message rows for [roomId].
  /// The [ChatScreen] maps these to [ChatMessage] objects.
  Stream<List<Map<String, dynamic>>> messagesStream(String roomId) =>
      _repo.messagesStream(roomId);

  /// Supabase Realtime stream of chat rooms (for unread-badge updates).
  Stream<List<ChatRoom>> roomsStream(String userId) =>
      _repo.roomsStream(userId);

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _sendSystem(String roomId, String content) =>
      _repo.insertMessage(ChatMessage(
        id: _uuid.v4(),
        roomId: roomId,
        senderId: '',
        senderName: 'System',
        content: content,
        messageType: MessageType.system,
        createdAt: DateTime.now(),
      ));

  static String _truncate(String s) =>
      s.length > 80 ? '${s.substring(0, 80)}…' : s;
}
