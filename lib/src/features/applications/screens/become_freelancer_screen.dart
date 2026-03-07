import 'package:flutter/material.dart';

class BecomeFreelancerScreen extends StatelessWidget {
  const BecomeFreelancerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Freelancer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              'Activate freelancer mode',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete your public profile to unlock service offerings, job applications, milestones, and ratings.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            const TextField(decoration: InputDecoration(labelText: 'Professional title')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Skills')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Experience summary'), maxLines: 4),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Portfolio link')),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: const Color(0xFF4F46E5),
              ),
              child: const Text('Activate Freelancer Mode'),
            ),
          ],
        ),
      ),
    );
  }
}
