import 'package:flutter/material.dart';

import '../../../routing/app_router.dart';
import '../../../shared/enums/notification_type.dart';
import '../../../state/app_state.dart';
import '../../applications/screens/service_orders_page.dart';
import '../../chat/screens/chat_screen.dart';
import '../models/in_app_notification.dart';

/// Full-screen inbox for in-app notifications.
///
/// Opened from the notification bell in [MainShell].
/// Marks all notifications read on open and supports tap-to-navigate.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await AppState.instance.loadNotifications();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    await AppState.instance.markAllNotificationsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read.')),
      );
    }
  }

  Future<void> _onTap(InAppNotification n) async {
    // Mark read
    if (!n.isRead) {
      await AppState.instance.markNotificationRead(n.id);
    }

    if (!mounted) return;

    // Chat message notification → open the chat room directly
    if (n.type == NotificationType.newChatMessage &&
        n.linkedChatRoomId != null) {
      // Try to find the room in the already-loaded list
      final rooms = AppState.instance.chatRooms;
      final room = rooms.where((r) => r.id == n.linkedChatRoomId).firstOrNull;

      if (room != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
        );
      } else {
        // Room not loaded yet — go to the chat list so the user can find it
        Navigator.pushNamed(context, AppRoutes.chatList);
      }
      return;
    }

    // New service order → freelancer goes straight to Incoming Orders
    if (n.type == NotificationType.orderPlaced) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServiceOrdersPage()),
      );
      return;
    }

    // Deep-link to project if available
    if (n.linkedProjectId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.transactions,
        arguments: n.linkedProjectId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          ListenableBuilder(
            listenable: AppState.instance,
            builder: (_, __) {
              final hasUnread =
                  AppState.instance.unreadNotificationCount > 0;
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton.icon(
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Mark all read'),
                onPressed: _markAllRead,
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: AppState.instance,
              builder: (context, _) {
                final notifs = AppState.instance.notifications;
                if (notifs.isEmpty) {
                  return _buildEmpty();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    await AppState.instance.loadNotifications();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) =>
                        _NotifTile(n: notifs[i], onTap: () => _onTap(notifs[i])),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No notifications yet.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
}

// ── Tile ────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.n, required this.onTap});
  final InAppNotification n;
  final VoidCallback onTap;

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hh:$mm';

    if (diff.inMinutes < 60) return timeStr;           // e.g. "14:32"
    if (diff.inDays < 1) return '$timeStr (today)';   // e.g. "09:05 (today)"
    if (diff.inDays < 2) return 'Yesterday $timeStr'; // e.g. "Yesterday 18:44"
    if (diff.inDays < 7) return '${diff.inDays}d ago $timeStr';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = n.type.color;
    final unread = !n.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread
            ? color.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(n.type.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(n.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Navigate chevron if linked to a project, chat room, or incoming order
            if (n.linkedProjectId != null ||
                n.linkedChatRoomId != null ||
                n.type == NotificationType.orderPlaced)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child:
                    Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
