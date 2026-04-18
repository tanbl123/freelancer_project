import 'package:flutter/material.dart';

/// The category of a chat room, which determines participants and permissions.
enum ChatRoomType {
  /// Direct message between any two users (pre/post application, general inquiry).
  direct,

  /// Project-scoped room visible only to the client and freelancer of that project.
  project,

  /// Admin ↔ appellant conversation tied to an open appeal case.
  appeal,

  /// Admin ↔ both dispute parties conversation tied to an open dispute.
  dispute;

  static ChatRoomType fromString(String v) =>
      ChatRoomType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ChatRoomType.direct,
      );

  String get displayName => switch (this) {
        ChatRoomType.direct  => 'Direct Message',
        ChatRoomType.project => 'Project Chat',
        ChatRoomType.appeal  => 'Appeal',
        ChatRoomType.dispute => 'Dispute',
      };

  IconData get icon => switch (this) {
        ChatRoomType.direct  => Icons.chat_bubble_outline,
        ChatRoomType.project => Icons.assignment_outlined,
        ChatRoomType.appeal  => Icons.gavel_outlined,
        ChatRoomType.dispute => Icons.balance_outlined,
      };

  Color get color => switch (this) {
        ChatRoomType.direct  => Colors.blue,
        ChatRoomType.project => Colors.green,
        ChatRoomType.appeal  => Colors.purple,
        ChatRoomType.dispute => Colors.deepOrange,
      };
}
