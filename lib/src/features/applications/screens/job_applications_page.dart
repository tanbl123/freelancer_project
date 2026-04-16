import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../services/file_storage_service.dart';
import '../../../state/app_state.dart';
import '../models/application_item.dart';
import 'apply_form_page.dart';

class JobApplicationsPage extends StatefulWidget {
  const JobApplicationsPage({super.key});

  @override
  State<JobApplicationsPage> createState() => _JobApplicationsPageState();
}

class _JobApplicationsPageState extends State<JobApplicationsPage> {
  @override
  void initState() {
    super.initState();
    AppState.instance.reloadApplications();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isFreelancer = user?.role == 'freelancer';

    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      floatingActionButton: isFreelancer
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApplyFormPage()),
              ).then((_) => AppState.instance.reloadApplications()),
              icon: const Icon(Icons.send),
              label: const Text('Apply'),
            )
          : null,
      // Real-time StreamBuilder — Module 2 advanced feature
      body: StreamBuilder<List<ApplicationItem>>(
        stream: AppState.instance.applicationsStream,
        initialData: AppState.instance.userApplications,
        builder: (context, snapshot) {
          final allApps = snapshot.data ?? AppState.instance.userApplications;

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
        },
      ),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  const _ApplicationCard({required this.item, required this.currentUser});
  final ApplicationItem item;
  final dynamic currentUser;

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

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
    }
  }

  Future<void> _toggleVoicePlayback() async {
    final path = widget.item.voicePitchUrl;
    if (path == null || !FileStorageService.instance.fileExists(path)) return;
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await _player.play(DeviceFileSource(path));
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final user = widget.currentUser;
    final isClientView =
        user?.role == 'client' && item.clientId == user?.uid;
    final isFreelancerView =
        user?.role == 'freelancer' && item.freelancerId == user?.uid;
    final statusColor = _statusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/profile/view',
                    arguments: item.freelancerId,
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    child: Text(item.freelancerName[0].toUpperCase()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/profile/view',
                      arguments: item.freelancerId,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(item.freelancerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 4),
                            const Text('›',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                        Text('Job: ${item.jobId}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
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
            Text(item.proposalMessage,
                style: const TextStyle(height: 1.4)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                Text('RM ${item.expectedBudget.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                Text(' ${item.timelineDays} days',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            // Resume + voice pitch attachments
            if (item.resumeUrl != null || item.voicePitchUrl != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (item.resumeUrl != null &&
                      FileStorageService.instance.fileExists(item.resumeUrl))
                    ActionChip(
                      avatar: const Icon(Icons.description, size: 14),
                      label: const Text('Resume'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Resume: ${item.resumeUrl}')),
                        );
                      },
                    ),
                  if (item.voicePitchUrl != null &&
                      FileStorageService.instance
                          .fileExists(item.voicePitchUrl))
                    ActionChip(
                      avatar: Icon(
                          _isPlaying ? Icons.stop : Icons.play_arrow,
                          size: 14),
                      label:
                          Text(_isPlaying ? 'Stop' : 'Voice Pitch'),
                      visualDensity: VisualDensity.compact,
                      onPressed: _toggleVoicePlayback,
                    ),
                ],
              ),
            ],

            // Client actions (accept/reject)
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
                        const SnackBar(content: Text('Application rejected.')),
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

            // Freelancer actions (edit/withdraw)
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
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.orange),
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
    );
  }

  void _confirmAccept(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Application'),
        content: Text(
            'Accept ${widget.item.freelancerName}\'s proposal?\n\nAll other applications for this job will be automatically rejected and a project will be created.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await AppState.instance.acceptApplication(widget.item);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Application accepted! Project created.')),
                );
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
