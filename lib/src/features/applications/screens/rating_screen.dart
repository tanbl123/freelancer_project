import 'package:flutter/material.dart';

class RatingScreen extends StatelessWidget {
  const RatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Rating')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              'Rate completed work',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reviews are only available after a project is completed.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            Row(
              children: List.generate(
                5,
                (index) => const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.star_rounded, size: 34, color: Color(0xFFF59E0B)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const TextField(
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Write feedback',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}
