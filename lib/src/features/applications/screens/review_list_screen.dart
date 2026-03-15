import 'package:flutter/material.dart';

class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reviews = [
      {'name': 'Alex Johnson', 'rating': '5.0', 'comment': 'Very professional and fast delivery.'},
      {'name': 'Sarah Lee', 'rating': '4.5', 'comment': 'Good communication and clean design work.'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews & Ratings', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/editReview'),
            icon: const Icon(Icons.edit_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: reviews.map((item) {
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.person, color: Color(0xFF4F46E5)),
              ),
              title: Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(item['comment']!),
              ),
              trailing: Text(item['rating']!, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
            ),
          );
        }).toList(),
      ),
    );
  }
}
