import 'package:flutter/material.dart';

class MilestoneDetailScreen extends StatelessWidget {
  const MilestoneDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Milestone Detail', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text('UI Screen Delivery', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Amount: RM 300 • Deadline: 10 Mar 2026\nStatus: Pending Review'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.upload_file_rounded),
              title: Text('Deliverables'),
              subtitle: Text('wireframe_v2.pdf, ui_mockup.fig'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Client can review deliverables before approval. Freelancer can update details before approval.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/deliverableSubmission'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('Open Deliverable Screen'),
          ),
        ],
      ),
    );
  }
}
