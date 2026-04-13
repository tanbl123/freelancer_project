import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../config/firebase_bootstrap.dart';
import '../controllers/applications_controller.dart';
import '../models/application_item.dart';

class JobApplicationsPage extends StatefulWidget {
  const JobApplicationsPage({super.key});

  @override
  State<JobApplicationsPage> createState() => _JobApplicationsPageState();
}

class _JobApplicationsPageState extends State<JobApplicationsPage> {
  final _controller = ApplicationsController();
  static const _previewJobId = 'preview-job-1';

  List<ApplicationItem> get _previewApplications => const [
        ApplicationItem(
          id: 'app-1',
          jobId: _previewJobId,
          clientId: 'client-1',
          freelancerId: 'fr-1',
          freelancerName: 'Tan Boon Leong',
          proposalMessage: 'Can start immediately, 2 milestones, daily updates.',
          expectedBudget: 600,
          timelineDays: 7,
          status: ApplicationStatus.pending,
        ),
        ApplicationItem(
          id: 'app-2',
          jobId: _previewJobId,
          clientId: 'client-1',
          freelancerId: 'fr-2',
          freelancerName: 'Yu Shen',
          proposalMessage: 'Includes testing + deployment notes.',
          expectedBudget: 750,
          timelineDays: 10,
          status: ApplicationStatus.accepted,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: FirebaseBootstrap.isEnabled
          ? StreamBuilder<List<ApplicationItem>>(
              stream: _controller.streamApplicationsForJob(_previewJobId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const Center(child: Text('No proposals submitted yet.'));
                }
                return _ApplicationList(items: items);
              },
            )
          : _ApplicationList(
              items: _previewApplications,
              bannerText: 'Preview mode: waiting for Firebase project connection.',
            ),
    );
  }
}

class _ApplicationList extends StatelessWidget {
  const _ApplicationList({required this.items, this.bannerText});

  final List<ApplicationItem> items;
  final String? bannerText;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (bannerText == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (bannerText != null && index == 0) {
          return Card(
            color: Colors.lightBlue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(bannerText!),
            ),
          );
        }

        final actualIndex = bannerText == null ? index : index - 1;
        final item = items[actualIndex];
        return Card(
          child: ListTile(
            title: Text(item.freelancerName),
            subtitle: Text(
              '${item.proposalMessage}\nRM ${item.expectedBudget.toStringAsFixed(0)} • ${item.timelineDays} days',
            ),
            isThreeLine: true,
            trailing: Chip(label: Text(item.status.name.toUpperCase())),
          ),
        );
      },
    );
  }
}
