import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/milestone_item.dart';

class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final milestones = AppState.instance.milestones;
        final total = milestones.fold<double>(0, (sum, m) => sum + m.paymentAmount);
        final paid = milestones
            .where((m) => m.status == MilestoneStatus.approved || m.status == MilestoneStatus.locked)
            .fold<double>(0, (sum, m) => sum + m.paymentAmount);

        return Scaffold(
          appBar: AppBar(title: const Text('Project & Milestones')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddMilestoneDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Milestone'),
          ),
          body: milestones.isEmpty
              ? const Center(child: Text('No milestones yet. Tap + to add one.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: [
                    // Summary card
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Budget',
                                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                                  Text('RM ${total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Paid Out',
                                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                                  Text('RM ${paid.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Progress',
                                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                                Text(
                                  total > 0 ? '${(paid / total * 100).toStringAsFixed(0)}%' : '0%',
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...milestones.map((m) => _MilestoneCard(milestone: m)),
                  ],
                ),
        );
      },
    );
  }

  void _showAddMilestoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddMilestoneDialog(),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone});
  final MilestoneItem milestone;

  Color _statusColor() {
    switch (milestone.status) {
      case MilestoneStatus.approved:
      case MilestoneStatus.locked:
        return Colors.green;
      case MilestoneStatus.submitted:
        return Colors.blue;
      case MilestoneStatus.draft:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    milestone.title,
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
                    milestone.status.name.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(milestone.description),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                Text('RM ${milestone.paymentAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                Text(
                  ' ${milestone.deadline.toLocal().toString().split(' ').first}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            if (!milestone.isLocked) ...[
              const Divider(height: 16),
              _StatusActions(milestone: milestone),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({required this.milestone});
  final MilestoneItem milestone;

  @override
  Widget build(BuildContext context) {
    if (milestone.status == MilestoneStatus.draft) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.upload, size: 16),
            label: const Text('Submit'),
            onPressed: () {
              AppState.instance.updateMilestoneStatus(
                  milestone.id, MilestoneStatus.submitted);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Milestone submitted for review.')),
              );
            },
          ),
        ],
      );
    }
    if (milestone.status == MilestoneStatus.submitted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('Revise'),
            onPressed: () {
              AppState.instance.updateMilestoneStatus(
                  milestone.id, MilestoneStatus.draft);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Milestone moved back to draft.')),
              );
            },
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Approve'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              AppState.instance.updateMilestoneStatus(
                  milestone.id, MilestoneStatus.approved);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Milestone approved! Payment released.')),
              );
            },
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _AddMilestoneDialog extends StatefulWidget {
  const _AddMilestoneDialog();

  @override
  State<_AddMilestoneDialog> createState() => _AddMilestoneDialogState();
}

class _AddMilestoneDialogState extends State<_AddMilestoneDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final milestone = MilestoneItem(
      id: AppState.instance.newId,
      projectId: 'project-1',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      deadline: _deadline,
      paymentAmount: double.tryParse(_amountController.text) ?? 0,
      status: MilestoneStatus.draft,
    );
    AppState.instance.addMilestone(milestone);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Milestone added!')),
    );
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Milestone'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount (RM)',
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
              OutlinedButton.icon(
                onPressed: _pickDeadline,
                icon: const Icon(Icons.calendar_today),
                label: Text('Deadline: ${_deadline.toLocal().toString().split(' ').first}'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
