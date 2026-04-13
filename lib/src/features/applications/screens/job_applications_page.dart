import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/application_item.dart';

class JobApplicationsPage extends StatelessWidget {
  const JobApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.currentUser;
        final apps = AppState.instance.applications;
        final isFreelancer = user?.role == 'freelancer';

        return Scaffold(
          appBar: AppBar(title: const Text('Applications')),
          floatingActionButton: isFreelancer
              ? FloatingActionButton.extended(
                  onPressed: () => _showApplyDialog(context),
                  icon: const Icon(Icons.send),
                  label: const Text('Apply'),
                )
              : null,
          body: apps.isEmpty
              ? const Center(child: Text('No applications yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final item = apps[index];
                    return _ApplicationCard(
                      item: item,
                      currentUserId: user?.uid ?? '',
                      isClient: user?.role == 'client',
                    );
                  },
                ),
        );
      },
    );
  }

  void _showApplyDialog(BuildContext context) {
    final posts = AppState.instance.posts
        .where((p) => p.type == PostType.jobRequest)
        .toList();
    if (posts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No job listings available to apply to.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _ApplyDialog(posts: posts),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.item,
    required this.currentUserId,
    required this.isClient,
  });

  final ApplicationItem item;
  final String currentUserId;
  final bool isClient;

  Color _statusColor() {
    switch (item.status) {
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

  @override
  Widget build(BuildContext context) {
    final isClientView = isClient && item.clientId == currentUserId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.freelancerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor().withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    item.status.name.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.proposalMessage),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                Text('RM ${item.expectedBudget.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                Text(' ${item.timelineDays} days',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                if (item.jobId.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.work_outline, size: 14, color: Colors.grey),
                  Expanded(
                    child: Text(
                      ' Job: ${item.jobId}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            // Client actions
            if (isClientView && item.status == ApplicationStatus.pending) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
                    onPressed: () {
                      AppState.instance.updateApplicationStatus(
                          item.id, ApplicationStatus.accepted);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Application accepted!')),
                      );
                    },
                  ),
                ],
              ),
            ],
            // Freelancer withdraw action
            if (!isClientView &&
                item.freelancerId == currentUserId &&
                item.status == ApplicationStatus.pending) ...[
              const Divider(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Withdraw'),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  onPressed: () {
                    AppState.instance.updateApplicationStatus(
                        item.id, ApplicationStatus.withdrawn);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application withdrawn.')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ApplyDialog extends StatefulWidget {
  const _ApplyDialog({required this.posts});
  final List<dynamic> posts;

  @override
  State<_ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<_ApplyDialog> {
  final _proposalController = TextEditingController();
  final _budgetController = TextEditingController();
  final _daysController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedJobId;

  @override
  void dispose() {
    _proposalController.dispose();
    _budgetController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a job.')),
      );
      return;
    }
    final user = AppState.instance.currentUser!;
    final job = widget.posts.firstWhere((p) => p.id == _selectedJobId);
    final app = ApplicationItem(
      id: AppState.instance.newId,
      jobId: _selectedJobId!,
      clientId: job.ownerId,
      freelancerId: user.uid,
      freelancerName: user.displayName,
      proposalMessage: _proposalController.text.trim(),
      expectedBudget: double.tryParse(_budgetController.text) ?? 0,
      timelineDays: int.tryParse(_daysController.text) ?? 7,
      status: ApplicationStatus.pending,
      createdAt: DateTime.now(),
    );
    AppState.instance.addApplication(app);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application submitted!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Application'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedJobId,
                  decoration: const InputDecoration(
                    labelText: 'Select Job',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.posts
                      .map<DropdownMenuItem<String>>((p) => DropdownMenuItem(
                            value: p.id as String,
                            child: Text(p.title as String, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedJobId = v),
                  validator: (v) => v == null ? 'Please select a job' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _proposalController,
                  decoration: const InputDecoration(
                    labelText: 'Proposal Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _budgetController,
                  decoration: const InputDecoration(
                    labelText: 'Your Quote (RM)',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _daysController,
                  decoration: const InputDecoration(
                    labelText: 'Timeline (days)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (int.tryParse(v) == null) return 'Enter a whole number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
