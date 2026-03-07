import 'package:flutter/material.dart';

import '../models/models.dart';
import '../../../common_widgets/common_widgets.dart';
import 'apply_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final JobPost job;
  const JobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(job.owner, style: TextStyle(color: Colors.grey.shade700)),
                const Spacer(),
                const Icon(Icons.schedule_outlined, size: 18),
                const SizedBox(width: 6),
                Text(job.deadline),
              ],
            ),
            const SizedBox(height: 16),
            InfoTile(label: 'Budget', value: 'RM ${job.budget.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            Text(job.description, style: TextStyle(color: Colors.grey.shade800, height: 1.5)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: job.skills.map((skill) => Chip(label: Text(skill))).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ApplyScreen()),
                  );
                },
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Apply for This Job'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
