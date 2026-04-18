import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/enums/chat_room_type.dart';
import '../../../state/app_state.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';

/// Full-screen chat interface for a single [ChatRoom].
///
/// ## Realtime design
/// On [initState] the screen subscribes to a Supabase Realtime channel for
/// the room via [ChatService.messagesStream]. Each emission from the stream
/// replaces the local message list, guaranteeing the UI stays in sync with
/// remote inserts even when another user types.
///
/// ## Date grouping
/// Messages are grouped into visual sections by calendar date.
/// If two consecutive messages are from the same sender and within 2 minutes
/// of each other, the sender avatar / name is suppressed to reduce noise.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.room});
  final ChatRoom room;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  StreamSubscription<List<Map<String, dynamic>>>? _msgSub;

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  late ChatRoom _room;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _loadHistory();
    _subscribeToRealtime();
    // Mark read as soon as the screen opens
    AppState.instance.markChatRoomRead(_room.id);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _msgSub?.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final msgs = await AppState.instance.loadChatMessages(_room.id);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _subscribeToRealtime() {
    _msgSub = AppState.instance.chatService
        .messagesStream(_room.id)
        .listen((rows) {
      if (!mounted) return;
      final fresh =
          rows.map(ChatMessage.fromMap).toList();
      setState(() => _messages = fresh);
      // Mark read whenever new messages arrive while the screen is open
      AppState.instance.markChatRoomRead(_room.id);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _inputCtrl.clear();

    final err = await AppState.instance.sendChatMessage(_room, text);
    if (mounted) {
      setState(() => _sending = false);
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  // ── Permission guard ───────────────────────────────────────────────────────

  bool get _canMessage {
    final user = AppState.instance.currentUser;
    if (user == null) return false;
    return AppState.instance.chatService.canMessage(user, _room);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final myId = AppState.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: _AppBarTitle(room: _room),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          // Room type info banner for admin / appeal / dispute rooms
          if (_room.type.name != 'direct' &&
              _room.type.name != 'project')
            _ContextBanner(room: _room),

          // Message list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Say hello! 👋',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final prev =
                              i > 0 ? _messages[i - 1] : null;

                          // Date separator
                          final showDate = prev == null ||
                              !_sameDay(prev.createdAt, msg.createdAt);

                          // Suppress avatar/name if same sender within 2 min
                          final showSender = msg.senderId != prev?.senderId ||
                              (msg.createdAt
                                      .difference(
                                          prev?.createdAt ?? DateTime(0))
                                      .inMinutes >
                                  2);

                          return Column(
                            children: [
                              if (showDate) _DateChip(date: msg.createdAt),
                              if (msg.isSystem)
                                _SystemMessage(message: msg)
                              else
                                _MessageBubble(
                                  message: msg,
                                  isMine: msg.isMine(myId),
                                  showSender: showSender,
                                ),
                            ],
                          );
                        },
                      ),
          ),

          // Input bar
          _InputBar(
            controller: _inputCtrl,
            enabled: _canMessage,
            sending: _sending,
            onSend: _send,
            disabledHint: _canMessage
                ? null
                : 'You cannot send messages here.',
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.room});
  final ChatRoom room;

  @override
  Widget build(BuildContext context) {
    final color = room.type.color;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(room.type.icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(room.type.displayName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              if (room.projectId != null)
                Text('Project chat',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.room});
  final ChatRoom room;

  @override
  Widget build(BuildContext context) {
    final color = room.type.color;
    final text = switch (room.type) {
      ChatRoomType.appeal =>
        'This is your appeal support chat. An admin will respond here.',
      ChatRoomType.dispute =>
        'Dispute chat — payment is paused. Admin is mediating.',
      _ => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(room.type.icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.black54)),
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: Colors.black54, height: 1.4),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSender,
  });

  final ChatMessage message;
  final bool isMine;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bubbleColor =
        isMine ? cs.primaryContainer : cs.surfaceContainerHighest;
    final textColor =
        isMine ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(
        top: showSender ? 8 : 2,
        bottom: 0,
        left: isMine ? 48 : 0,
        right: isMine ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender && !isMine)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                message.senderName,
                style: tt.labelSmall?.copyWith(
                    color: cs.outline, fontWeight: FontWeight.w600),
              ),
            ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.content,
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  _fmt(message.createdAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: textColor.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
    this.disabledHint,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!enabled && disabledHint != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: cs.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: cs.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(disabledHint!,
                  style: TextStyle(color: cs.outline, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled && !sending,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: onSend,
                    style: IconButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
