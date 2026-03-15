import 'package:flutter/material.dart';

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = [
      {'title': 'Build a mobile app', 'type': 'Job Request', 'status': 'Active'},
      {'title': 'SEO Content Writing Service', 'type': 'Service Offering', 'status': 'Draft'},
      {'title': 'Logo Design Needed', 'type': 'Job Request', 'status': 'Closed'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/createPost'),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: posts.map((post) {
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(post['title']!, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${post['type']} • ${post['status']}'),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.pushNamed(context, '/editPost');
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
