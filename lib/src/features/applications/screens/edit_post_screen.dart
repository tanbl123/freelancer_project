import 'package:flutter/material.dart';

class EditPostScreen extends StatelessWidget {
  const EditPostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Posting', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Title'),
            controller: TextEditingController(text: 'Build a mobile app'),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 4,
            controller: TextEditingController(text: 'Need a freelancer to build a mobile app UI.'),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Budget / Price'),
            controller: TextEditingController(text: '3000'),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Deadline / Timeline'),
            controller: TextEditingController(text: '20 Mar 2026'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
