import '../../../services/supabase_service.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';

/// Thin data-access wrapper for chat rooms and messages.
/// All business logic and permission checks live in [ChatService].
class ChatRepository {
  const ChatRepository(this._db);
  final SupabaseService _db;

  // ── Rooms ──────────────────────────────────────────────────────────────────

  Future<List<ChatRoom>> getRoomsForUser(String userId) =>
      _db.getChatRoomsForUser(userId);

  Future<ChatRoom?> getById(String id) => _db.getChatRoomById(id);

  Future<ChatRoom?> getDirectRoom(String userId1, String userId2) =>
      _db.getDirectRoom(userId1, userId2);

  Future<ChatRoom?> getProjectRoom(String projectId) =>
      _db.getProjectRoom(projectId);

  Future<ChatRoom?> getAppealRoom(String appealId) =>
      _db.getAppealRoom(appealId);

  Future<ChatRoom?> getDisputeRoom(String disputeId) =>
      _db.getDisputeRoom(disputeId);

  Future<ChatRoom> insert(ChatRoom room) => _db.insertChatRoom(room);

  Future<void> update(ChatRoom room) => _db.updateChatRoom(room);

  Future<void> addParticipant(String roomId, String userId) =>
      _db.addParticipantToRoom(roomId, userId);

  // ── Messages ───────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> getMessages(
    String roomId, {
    int limit = 50,
    int offset = 0,
  }) =>
      _db.getMessagesForRoom(roomId, limit: limit, offset: offset);

  Future<ChatMessage> insertMessage(ChatMessage message) =>
      _db.insertChatMessage(message);

  /// Realtime stream of messages for a room (ordered oldest-first).
  Stream<List<Map<String, dynamic>>> messagesStream(String roomId) =>
      _db.chatMessagesStream(roomId);

  /// Realtime stream of chat rooms the user is a member of.
  Stream<List<ChatRoom>> roomsStream(String userId) =>
      _db.chatRoomsStream(userId);

  // ── Read tracking ──────────────────────────────────────────────────────────

  Future<void> markRead(String roomId, String userId) =>
      _db.markRoomRead(roomId, userId);

  Future<Map<String, DateTime>> getReadTimestamps(String userId) =>
      _db.getChatReadTimestamps(userId);
}
