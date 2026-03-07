import 'package:flutter/material.dart';
import '../data/mock_data.dart';

class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'New':
        return const Color(0xFF2563EB);
      case 'Shortlisted':
        return const Color(0xFF059669);
      default:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.mic_rounded),
              title: Text('Voice pitch feature'),
              subtitle: Text('Advanced feature placeholder for 30-second voice note recording'),
            ),
          ),
          const SizedBox(height: 12),
          ...MockData.applications.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(item['role']!, style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Budget: ${item['price']}'),
                        const SizedBox(width: 14),
                        Text('Timeline: ${item['timeline']}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: _statusColor(item['status']!).withOpacity(.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item['status']!,
                            style: TextStyle(
                              color: _statusColor(item['status']!),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(onPressed: () {}, child: const Text('Reject')),
                        FilledButton(
                          onPressed: () => Navigator.pushNamed(context, '/milestones'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
