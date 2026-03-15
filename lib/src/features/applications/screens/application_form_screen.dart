import 'package:flutter/material.dart';

class ApplicationFormScreen extends StatelessWidget {
  const ApplicationFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Proposal', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text('Build a React Native Mobile App', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Budget: RM 2000 - RM 5000'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Expected budget')),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Timeline')),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Cover letter'), maxLines: 5),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.description_rounded),
              title: Text('Attach resume'),
              subtitle: Text('Placeholder for resume upload or linked profile'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.mic_rounded),
              title: Text('Voice pitch recording'),
              subtitle: Text('Advanced feature placeholder for 30-second voice note'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('Submit Proposal'),
          ),
        ],
      ),
    );
  }
}
