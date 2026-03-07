import 'package:flutter/material.dart';

import '../models/models.dart';
import '../../../common_widgets/common_widgets.dart';

class MilestoneDetailScreen extends StatelessWidget {
  final Milestone milestone;
  const MilestoneDetailScreen({super.key, required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Milestone Details')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(milestone.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StatusBadge(status: milestone.status),
            const SizedBox(height: 16),
            Text(milestone.description, style: TextStyle(color: Colors.grey.shade800, height: 1.5)),
            const SizedBox(height: 16),
            InfoTile(label: 'Deadline', value: milestone.deadline),
            const SizedBox(height: 10),
            InfoTile(label: 'Payment', value: 'RM ${milestone.amount.toStringAsFixed(0)}'),
            const SizedBox(height: 18),
            const FeatureBanner(
              title: 'Digital Signature Pad',
              subtitle: 'Client signs on screen to approve and lock the milestone.',
              icon: Icons.draw_outlined,
            ),
            const SizedBox(height: 12),
            const FeatureBanner(
              title: 'Stripe Sandbox Payment',
              subtitle: 'Simulated secure payment after milestone approval.',
              icon: Icons.credit_card_outlined,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Upload Deliverable'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Approve & Pay'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
