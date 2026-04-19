import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/application_item.dart';
import 'apply_form_page.dart';

class JobApplicationsPage extends StatelessWidget {
  const JobApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        automaticallyImplyLeading: false,
      ),
      body: const JobApplicationsBody(),
    );
  }
}

/// The scrollable body of the job-applications screen, extracted so it can
/// be embedded inside [RaDashboardScreen]'s TabBarView without a double-Scaffold.
class JobApplicationsBody extends StatefulWidget {
  const JobApplicationsBody({super.key});

  @override
  State<JobApplicationsBody> createState() => _JobApplicationsBodyState();
}

class _JobApplicationsBodyState extends State<JobApplicationsBody> {
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChanged);
    AppState.instance.reloadApplications();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isFreelancer = user?.role == UserRole.freelancer;
    final allApps = AppState.instance.userApplications;

    if (allApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              isFreelancer
                  ? 'You haven\'t applied to any jobs yet.\nTap + to submit a proposal.'
                  : 'No applications have been submitted to your jobs yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => AppState.instance.reloadApplications(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: allApps.length,
        itemBuilder: (context, index) => _ApplicationCard(
          item: allApps[index],
          currentUser: user,
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.item, required this.currentUser});
  final ApplicationItem item;
  final dynamic currentUser;

  Color _statusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.withdrawn:
        return Colors.grey;
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.convertedToProject:
        return Colors.blue;
    }
  }

  /// Look up job title from the new JobPost list; fall back to truncated ID.
  String _jobTitle() {
    final posts = AppState.instance.jobPosts;
    try {
      return posts.firstWhere((p) => p.id == item.jobId).title;
    } catch (_) {
      // Not found — show a short version of the ID
      return 'Job ${item.jobId.length > 8 ? item.jobId.substring(0, 8) : item.jobId}…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final isClientView =
        user?.role == UserRole.client && item.clientId == user?.uid;
    final isFreelancerView =
        user?.role == UserRole.freelancer && item.freelancerId == user?.uid;
    final statusColor = _statusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/profile/view',
          arguments: item.freelancerId,
        ),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: applicant avatar + name + status badge ─────────
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(item.freelancerName[0].toUpperCase()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.freelancerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(
                        _jobTitle(),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    item.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Proposal text ──────────────────────────────────────────────
            Text(item.proposalMessage,
                style: const TextStyle(height: 1.4)),

            // ── Client actions (accept/reject) ─────────────────────────────
            if (isClientView && item.status == ApplicationStatus.pending) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red),
                    onPressed: () {
                      AppState.instance.updateApplicationStatus(
                          item.id, ApplicationStatus.rejected);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Application rejected.')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    onPressed: () => _confirmAccept(context),
                  ),
                ],
              ),
            ],

            // ── Freelancer actions (edit/withdraw) ─────────────────────────
            if (isFreelancerView &&
                item.status == ApplicationStatus.pending) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApplyFormPage(existing: item),
                      ),
                    ).then((_) => AppState.instance.reloadApplications()),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Withdraw'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.orange),
                    onPressed: () {
                      AppState.instance.updateApplicationStatus(
                          item.id, ApplicationStatus.withdrawn);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Application withdrawn.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _confirmAccept(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Application'),
        content: Text(
            'Accept ${item.freelancerName}\'s proposal?\n\nAll other applications for this job will be automatically rejected and a project will be created.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await AppState.instance.acceptApplication(item);
              if (context.mounted) {
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(err), backgroundColor: Colors.red),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Application accepted! Project created.')),
                  );
                }
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
