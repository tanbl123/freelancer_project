import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../../../common_widgets/common_widgets.dart';
import 'milestone_detail_screen.dart';

class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Milestones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FeatureBanner(
            title: 'Project Order Created',
            subtitle: 'This starts automatically when the client accepts an application.',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 12),
          ...AppData.milestones.map(
            (milestone) => GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MilestoneDetailScreen(milestone: milestone)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(milestone.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                        StatusBadge(status: milestone.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(milestone.description, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(milestone.deadline),
                        const Spacer(),
                        Text('RM ${milestone.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
