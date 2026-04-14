import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/milestone_item.dart';
import '../models/project_item.dart';
import 'milestone_form_page.dart';
import 'payment_simulator_page.dart';
import 'signature_pad_page.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  List<MilestoneItem> _milestones = [];
  ProjectItem? _project;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final milestones =
        await AppState.instance.getMilestonesForProject(widget.projectId);
    final project = AppState.instance.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (mounted) {
      setState(() {
        _milestones = milestones;
        _project = project;
        _loading = false;
      });
    }
  }

  Future<void> _approveFlow(MilestoneItem milestone) async {
    final signaturePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => SignaturePadPage(milestoneId: milestone.id)),
    );
    if (signaturePath == null || !mounted) return;

    final paymentToken = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentSimulatorPage(
          amount: milestone.paymentAmount,
          milestoneTitle: milestone.title,
        ),
      ),
    );
    if (paymentToken == null || !mounted) return;

    await AppState.instance
        .approveMilestone(milestone.id, signaturePath, paymentToken);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Milestone approved! Payment released.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isClient = user?.uid == _project?.clientId;
    final total = _milestones.fold<double>(0, (s, m) => s + m.paymentAmount);
    final paid = _milestones
        .where((m) => m.isLocked)
        .fold<double>(0, (s, m) => s + m.paymentAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text(_project?.jobTitle ?? 'Project Details'),
      ),
      floatingActionButton: (_project?.status == 'inProgress')
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MilestoneFormPage(projectId: widget.projectId),
                ),
              ).then((_) => _load()),
              icon: const Icon(Icons.add),
              label: const Text('Milestone'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  if (_project != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _project!.jobTitle ?? 'Project',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                _StatusBadge(status: _project!.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (isClient)
                              _InfoRow(
                                  Icons.code,
                                  'Freelancer',
                                  _project!.freelancerName ??
                                      _project!.freelancerId)
                            else
                              _InfoRow(
                                  Icons.business,
                                  'Client',
                                  _project!.clientName ??
                                      _project!.clientId),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _BudgetColumn('Total', total),
                              _BudgetColumn('Paid', paid,
                                  color: Colors.green.shade700),
                              _BudgetColumn('Remaining', total - paid,
                                  color: Colors.orange.shade700),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: total > 0 ? paid / total : 0,
                              minHeight: 8,
                              backgroundColor: Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            total > 0
                                ? '${(paid / total * 100).toStringAsFixed(0)}% completed'
                                : 'No milestones yet',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_milestones.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.task_outlined,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No milestones yet.\nTap + to add one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    const Text('Milestones',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._milestones.map(
                      (m) => _MilestoneCard(
                        milestone: m,
                        isClient: isClient,
                        projectStatus: _project?.status ?? '',
                        onApprove: () => _approveFlow(m),
                        onEdit: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MilestoneFormPage(
                              projectId: widget.projectId,
                              existing: m,
                            ),
                          ),
                        ).then((_) => _load()),
                        onDelete: () async {
                          await AppState.instance.deleteMilestone(m.id);
                          await _load();
                        },
                        onSubmit: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await AppState.instance.updateMilestoneStatus(
                              m.id, MilestoneStatus.submitted);
                          await _load();
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Milestone submitted for review.')),
                          );
                        },
                        onRevise: () async {
                          await AppState.instance.updateMilestoneStatus(
                              m.id, MilestoneStatus.draft);
                          await _load();
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _color {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: _color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _BudgetColumn extends StatelessWidget {
  const _BudgetColumn(this.label, this.amount, {this.color});
  final String label;
  final double amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(
          'RM ${amount.toStringAsFixed(0)}',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestone,
    required this.isClient,
    required this.projectStatus,
    required this.onApprove,
    required this.onEdit,
    required this.onDelete,
    required this.onSubmit,
    required this.onRevise,
  });

  final MilestoneItem milestone;
  final bool isClient;
  final String projectStatus;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final VoidCallback onRevise;

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
    final isLocked = milestone.isLocked;
    final isDraft = milestone.status == MilestoneStatus.draft;
    final isSubmitted = milestone.status == MilestoneStatus.submitted;
    final isInProgress = projectStatus == 'inProgress';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(milestone.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _statusColor().withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    milestone.status.name.toUpperCase(),
                    style: TextStyle(
                        color: _statusColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(milestone.description,
                style: const TextStyle(color: Colors.black87, height: 1.4)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                Text('RM ${milestone.paymentAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today,
                    size: 12, color: Colors.grey),
                Text(
                  ' ${milestone.deadline.toLocal().toString().split(' ').first}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            if (milestone.paymentToken != null) ...[
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Payment released',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ),
            ],
            if (isInProgress && !isLocked) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isClient && isDraft) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit',
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text('Submit'),
                      onPressed: onSubmit,
                    ),
                  ],
                  if (isClient && isSubmitted) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Request Revision'),
                      onPressed: onRevise,
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve & Pay'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green),
                      onPressed: onApprove,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
