import 'package:flutter/material.dart';

class EditReviewScreen extends StatelessWidget {
  const EditReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Review', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Update review',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(labelText: 'Rating'),
            controller: TextEditingController(text: '5'),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(labelText: 'Feedback'),
            maxLines: 5,
            controller: TextEditingController(text: 'Very professional and fast delivery.'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('Save Review'),
          ),
        ],
      ),
    );
  }
}
