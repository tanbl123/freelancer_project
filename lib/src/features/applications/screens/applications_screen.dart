import 'package:flutter/material.dart';
import '../../../common_widgets/common_widgets.dart';

class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FeatureBanner(
            title: 'Real-Time Updates',
            subtitle: 'Use StreamBuilder with Firebase or WebSockets for instant new applications.',
            icon: Icons.wifi_tethering_outlined,
          ),
          const SizedBox(height: 12),
          ...List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: Text('F${index + 1}')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Freelancer ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('UI/UX Designer • RM ${500 + (index * 100)}', style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEFF),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text('Pending'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Proposal includes attached resume and voice pitch introduction.'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(onPressed: () {}, child: const Text('Reject')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(onPressed: () {}, child: const Text('Accept')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
