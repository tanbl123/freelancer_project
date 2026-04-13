import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../config/firebase_bootstrap.dart';
import '../controllers/transactions_controller.dart';
import '../models/milestone_item.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  final _controller = TransactionsController();
  static const _previewProjectId = 'project-preview-1';

  List<MilestoneItem> get _previewMilestones => [
        MilestoneItem(
          id: 'ms-1',
          projectId: _previewProjectId,
          title: 'Draft 1',
          description: 'Base UI and architecture setup',
          deadline: DateTime.now().add(const Duration(days: 2)),
          paymentAmount: 200,
          status: MilestoneStatus.submitted,
        ),
        MilestoneItem(
          id: 'ms-2',
          projectId: _previewProjectId,
          title: 'Final Delivery',
          description: 'Final polish and handover',
          deadline: DateTime.now().add(const Duration(days: 7)),
          paymentAmount: 400,
          status: MilestoneStatus.draft,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project & Milestones')),
      body: FirebaseBootstrap.isEnabled
          ? StreamBuilder<List<MilestoneItem>>(
              stream: _controller.streamMilestones(_previewProjectId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const Center(child: Text('No milestones created yet.'));
                }
                return _MilestoneList(items: items);
              },
            )
          : _MilestoneList(
              items: _previewMilestones,
              bannerText: 'Preview mode: connect Firebase to see live milestones.',
            ),
    );
  }
}

class _MilestoneList extends StatelessWidget {
  const _MilestoneList({required this.items, this.bannerText});

  final List<MilestoneItem> items;
  final String? bannerText;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (bannerText == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (bannerText != null && index == 0) {
          return Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(bannerText!),
            ),
          );
        }
        final actualIndex = bannerText == null ? index : index - 1;
        final milestone = items[actualIndex];
        return Card(
          child: ListTile(
            title: Text(milestone.title),
            subtitle: Text(
              '${milestone.description}\nRM ${milestone.paymentAmount.toStringAsFixed(0)} • ${milestone.deadline.toLocal().toString().split(' ').first}',
            ),
            isThreeLine: true,
            trailing: Chip(label: Text(milestone.status.name.toUpperCase())),
          ),
        );
      },
    );
  }
}
