import 'package:flutter/material.dart';
import '../../../common_widgets/common_widgets.dart';

class RatingScreen extends StatelessWidget {
  const RatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Review')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rate the freelancer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                5,
                (index) => const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.star, color: Colors.amber, size: 34),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const AppTextField(
              label: 'Feedback Comments',
              icon: Icons.chat_bubble_outline,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            const FeatureBanner(
              title: 'Review Rule',
              subtitle: 'Only available after project completion with that specific freelancer.',
              icon: Icons.verified_outlined,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
