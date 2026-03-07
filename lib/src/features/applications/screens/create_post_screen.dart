import 'package:flutter/material.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create posting')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              'Create a new post',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this screen for job requests or service offerings.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Job Request')),
                ButtonSegment(value: 1, label: Text('Service Offering')),
              ],
              selected: const {0},
              onSelectionChanged: (newSelection) {},
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Title')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Description'), maxLines: 4),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Budget / Price')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Deadline / Timeline')),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.camera_alt_rounded),
                title: Text('Add image proof / portfolio'),
                subtitle: Text('Camera package placeholder'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF4F46E5),
              ),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
  }
}
