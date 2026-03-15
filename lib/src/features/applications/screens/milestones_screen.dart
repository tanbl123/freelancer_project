import 'package:flutter/material.dart';
import '../data/mock_data.dart';

class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project milestones', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.draw_rounded),
              title: const Text('Signature pad feature'),
              subtitle: const Text('Advanced feature placeholder for client approval with digital signature'),
              onTap: () => Navigator.pushNamed(context, '/signatureApproval'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.credit_card_rounded),
              title: const Text('Stripe sandbox simulation'),
              subtitle: const Text('Advanced feature placeholder for simulated milestone payment'),
              onTap: () => Navigator.pushNamed(context, '/paymentSimulation'),
            ),
          ),
          const SizedBox(height: 12),
          ...MockData.milestones.map(
                (item) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${item['amount']} • ${item['deadline']}'),
                ),
                trailing: Text(
                  item['status']!,
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pushNamed(context, '/milestoneDetail'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}