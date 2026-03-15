import 'package:flutter/material.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = [
      {'name': 'Emma Davis', 'message': 'I will send the mockups by tomorrow.', 'time': '2m ago', 'unread': '2'},
      {'name': 'James Wilson', 'message': 'The deployment is ready for review.', 'time': '1h ago', 'unread': '0'},
      {'name': 'Lisa Park', 'message': 'Thanks for the feedback!', 'time': '3h ago', 'unread': '0'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...chats.map(
            (chat) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFE0E7FF),
                      child: Icon(Icons.person, color: Color(0xFF4F46E5)),
                    ),
                    if (chat['unread'] != '0')
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat['unread']!,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(chat['name']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(chat['message']!, style: const TextStyle(color: Color(0xFF6B7280))),
                ),
                trailing: Text(chat['time']!, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                onTap: () => Navigator.pushNamed(context, '/chatDetail'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.forum_rounded),
              title: Text('Real-time chat'),
              subtitle: Text('Placeholder for project chat, meeting link, and file sharing'),
            ),
          ),
        ],
      ),
    );
  }
}
