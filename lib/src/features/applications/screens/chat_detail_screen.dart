import 'package:flutter/material.dart';

class ChatDetailScreen extends StatelessWidget {
  const ChatDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final messages = [
      {'mine': false, 'text': 'Hi, I have uploaded the first draft for review.'},
      {'mine': true, 'text': 'Thanks. I will check it tonight.'},
      {'mine': false, 'text': 'Sure. I can revise it after your feedback.'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Chat', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.video_call_outlined)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Project: Mobile App UI Design\nAdvanced placeholders: call meeting, send file, send image',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final mine = msg['mine'] as bool;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: mine ? const Color(0xFF4F46E5) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      msg['text'] as String,
                      style: TextStyle(color: mine ? Colors.white : const Color(0xFF111827)),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file_rounded)),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
