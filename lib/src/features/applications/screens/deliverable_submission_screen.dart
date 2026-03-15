import 'package:flutter/material.dart';

class DeliverableSubmissionScreen extends StatelessWidget {
  const DeliverableSubmissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Deliverable', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Milestone title'),
            controller: TextEditingController(text: 'UI Screen Delivery'),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(labelText: 'Submission note'),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.attach_file_rounded),
              title: Text('Upload deliverable files'),
              subtitle: Text('Placeholder for file/image/link submission'),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.visibility_rounded),
              title: Text('Client review status'),
              subtitle: Text('Pending client review'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('Submit Deliverable'),
          ),
        ],
      ),
    );
  }
}
