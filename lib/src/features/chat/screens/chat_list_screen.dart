import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/enums/chat_room_type.dart';
import '../../../state/app_state.dart';
import '../models/chat_room.dart';
import 'chat_screen.dart';

/// Full-screen list of all chat rooms the current user belongs to.
///
/// Rooms are sorted by last-message time (most recent first).
/// An unread dot badge is shown on rooms with new messages since last visit.
/// Tabs filter by room type: All | Direct (includes project chats) | Admin.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  StreamSubscription<List<ChatRoom>>? _roomsSub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
    _subscribeToRooms();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _roomsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppState.instance.loadChatRooms();
    if (mounted) setState(() => _loading = false);
  }

  void _subscribeToRooms() {
    final uid = AppState.instance.currentUser?.uid;
    if (uid == null) return;

    _roomsSub = AppState.instance.chatService
        .roomsStream(uid)
        .listen((rooms) async {
      if (!mounted) return;
      // Reload so unread map is recomputed
      await AppState.instance.loadChatRooms();
    });
  }

  List<ChatRoom> _filtered(ChatRoomType? type) {
    final rooms = AppState.instance.chatRooms;
    if (type == null) return rooms;
    return rooms.where((r) => r.type == type).toList();
  }

  /// Returns direct + project rooms merged, preserving the already-sorted
  /// (most-recent-first) order from AppState.
  List<ChatRoom> _directAndProjectRooms() {
    final rooms = AppState.instance.chatRooms;
    return rooms
        .where((r) =>
            r.type == ChatRoomType.direct || r.type == ChatRoomType.project)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Direct'),
            Tab(text: 'Admin'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: AppState.instance,
              builder: (_, __) => TabBarView(
                controller: _tabCtrl,
                children: [
                  _RoomList(rooms: _filtered(null), onRefresh: _load),
                  _RoomList(
                      rooms: _directAndProjectRooms(),
                      onRefresh: _load),
                  _RoomList(
                    rooms: [
                      ..._filtered(ChatRoomType.appeal),
                      ..._filtered(ChatRoomType.dispute),
                    ],
                    onRefresh: _load,
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Room list ─────────────────────────────────────────────────────────────────

class _RoomList extends StatelessWidget {
  const _RoomList({required this.rooms, required this.onRefresh});

  final List<ChatRoom> rooms;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('No conversations yet',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        itemCount: rooms.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 72),
        itemBuilder: (ctx, i) => _RoomTile(room: rooms[i]),
      ),
    );
  }
}

// ── Room tile ─────────────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});
  final ChatRoom room;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final myId = AppState.instance.currentUser?.uid ?? '';
    final hasUnread = AppState.instance.hasUnreadInRoom(room.id);
    final color = room.type.color;

    // Derive a display name for the room
    final label = _roomLabel(room, myId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 24,
            child: Icon(room.type.icon, color: color, size: 22),
          ),
          if (hasUnread)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: cs.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        label,
        style: tt.bodyLarge?.copyWith(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        room.lastMessage ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.bodySmall?.copyWith(
          color: hasUnread ? cs.onSurface : cs.outline,
          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: room.lastMessageAt != null
          ? Text(
              _relativeTime(room.lastMessageAt!),
              style: tt.labelSmall?.copyWith(
                color: hasUnread ? color : cs.outline,
                fontWeight:
                    hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
        );
      },
    );
  }

  String _roomLabel(ChatRoom room, String myId) {
    switch (room.type) {
      case ChatRoomType.direct:
        // Always show the other participant's real name.
        final otherId = room.otherParticipantId(myId);
        return AppState.instance.chatUserNames[otherId] ??
            room.lastSenderName ??
            'Direct Message';
      case ChatRoomType.project:
        return 'Project Chat';
      case ChatRoomType.appeal:
        return 'Appeal Support';
      case ChatRoomType.dispute:
        return 'Dispute';
    }
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hh:$mm';

    if (diff.inDays < 1) return timeStr;          // e.g. "14:32" (same day)
    if (diff.inDays < 2) return 'Yesterday';      // e.g. "Yesterday"
    if (diff.inDays < 7) return '${diff.inDays}d'; // e.g. "3d"
    return '${dt.day}/${dt.month}';               // e.g. "19/4"
  }
}
