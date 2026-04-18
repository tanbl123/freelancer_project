import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';
import '../../disputes/models/dispute_record.dart';
import '../../overdue/services/overdue_service.dart';
import '../models/milestone_item.dart';
import '../models/project_item.dart';
import '../services/project_service.dart';
import '../../payment/models/payment_record.dart';
import '../../payment/screens/checkout_screen.dart';
import '../../payment/screens/payment_status_screen.dart';
import 'milestone_plan_page.dart';
import 'milestone_plan_review_page.dart';
import 'project_completion_page.dart';
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
  DisputeRecord? _dispute;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final milestones =
        await AppState.instance.getMilestonesForProject(widget.projectId);
    final project = AppState.instance.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    // Load active dispute if project is disputed
    DisputeRecord? dispute;
    if (project != null && project.isDisputed) {
      dispute =
          await AppState.instance.loadDisputeForProject(widget.projectId);
    }

    if (mounted) {
      setState(() {
        _milestones = List.from(milestones)
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        _project = project;
        _dispute = dispute;
        _loading = false;
      });
    }
  }

  // ── Milestone approve (sign + pay) ─────────────────────────────────────────

  Future<void> _approveFlow(MilestoneItem milestone) async {
    // Step 1 — collect digital signature
    final signaturePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SignaturePadPage(
          contextId: milestone.id,
          promptText:
              'Sign to approve "${milestone.title}" and release payment.',
        ),
      ),
    );
    if (signaturePath == null || !mounted) return;

    // Step 2 — approve milestone and release escrow payout
    final messenger = ScaffoldMessenger.of(context);
    final err = await AppState.instance
        .approveAndPayMilestone(milestone, signaturePath);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Milestone approved! Payment released.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── Submit deliverable ─────────────────────────────────────────────────────

  Future<void> _submitDeliverable(MilestoneItem milestone) async {
    final urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Deliverable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milestone: "${milestone.title}"',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Deliverable URL or Description *',
                border: OutlineInputBorder(),
                hintText: 'https://… or describe the work completed',
              ),
              maxLines: 4,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (urlController.text.trim().isEmpty) return;
              Navigator.pop(ctx, urlController.text.trim());
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final err =
        await AppState.instance.submitMilestoneDeliverable(milestone, result);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Deliverable submitted for review.')),
      );
    }
  }

  // ── Reject deliverable ─────────────────────────────────────────────────────

  Future<void> _rejectMilestone(MilestoneItem milestone) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Deliverable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Provide a clear reason so the freelancer can revise:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, reasonController.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final err =
        await AppState.instance.rejectMilestone(milestone, result);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Milestone rejected.')));
    }
  }

  // ── Request extension ──────────────────────────────────────────────────────

  Future<void> _requestExtension(MilestoneItem milestone) async {
    int days = 7;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Request Deadline Extension'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How many additional days do you need?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () =>
                        setDlg(() => days = (days - 1).clamp(1, 90)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$days days',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        setDlg(() => days = (days + 1).clamp(1, 90)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, days),
              child: const Text('Request Extension'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final err =
        await AppState.instance.requestMilestoneExtension(milestone, result);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Extension of $result day(s) requested. '
                'Awaiting client approval.')),
      );
    }
  }

  // ── Cancel / Dispute ───────────────────────────────────────────────────────

  Future<void> _cancelProject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Project'),
        content: const Text(
            'Are you sure you want to cancel this project? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Project')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Project'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final err = await AppState.instance.cancelProject(_project!);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      await AppState.instance.reloadProjects();
      await _load();
    }
  }

  Future<void> _disputeProject() async {
    if (_project == null) return;
    // Navigate to the dedicated dispute creation screen
    final raised = await Navigator.pushNamed(
      context,
      AppRoutes.disputeCreate,
      arguments: _project!,
    );
    if (raised == true && mounted) {
      await AppState.instance.reloadProjects();
      await _load();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Project not found.')),
      );
    }

    final user = AppState.instance.currentUser!;
    final isClient = user.uid == _project!.clientId;
    final canModify =
        _project!.isInProgress || _project!.isPendingStart;
    final paymentRecord = AppState.instance.currentPaymentRecord;

    return Scaffold(
      appBar: AppBar(
        title: Text(_project!.jobTitle ?? 'Project Details'),
        actions: [
          // Payment status shortcut
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Payment Status',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PaymentStatusScreen(project: _project!),
              ),
            ),
          ),
          if (canModify)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'cancel') _cancelProject();
                if (v == 'dispute') _disputeProject();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(children: [
                    Icon(Icons.cancel_outlined, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Cancel Project'),
                  ]),
                ),
                if (_project!.isInProgress)
                  const PopupMenuItem(
                    value: 'dispute',
                    child: Row(children: [
                      Icon(Icons.gavel, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Raise Dispute'),
                    ]),
                  ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            _ProjectInfoCard(project: _project!, isClient: isClient),
            const SizedBox(height: 10),
            _BudgetCard(project: _project!, milestones: _milestones),
            const SizedBox(height: 10),
            // ── Payment status banner ─────────────────────────────────
            if (paymentRecord != null)
              _PaymentStatusBanner(payment: paymentRecord)
            else if (_project!.isInProgress && isClient)
              _PaymentNudgeBanner(project: _project!,
                  milestones: _milestones),
            // ── Overdue warning banner ────────────────────────────────
            ..._milestones
                .where((m) => m.isInProgress)
                .map((m) {
                  final status =
                      OverdueService.computeWarningStatus(m);
                  if (status == OverdueStatus.onTrack) {
                    return const SizedBox.shrink();
                  }
                  return _OverdueWarningBanner(
                    milestone: m,
                    status: status,
                    isFreelancer: !isClient,
                    onRequestExtension: isClient
                        ? null
                        : () => _requestExtension(m),
                  );
                }),
            const SizedBox(height: 6),
            ..._buildBody(context, isClient),
          ],
        ),
      ),
    );
  }

  // ── Status-specific body builders ─────────────────────────────────────────

  List<Widget> _buildBody(BuildContext context, bool isClient) {
    switch (_project!.status) {
      case ProjectStatus.pendingStart:
        return _buildPendingStartSection(context, isClient);
      case ProjectStatus.inProgress:
        return _buildInProgressSection(context, isClient);
      case ProjectStatus.completed:
        return _buildCompletedSection();
      case ProjectStatus.cancelled:
        return [
          _StatusBanner(
            icon: Icons.cancel,
            color: Colors.red,
            title: 'Project Cancelled',
          ),
        ];
      case ProjectStatus.disputed:
        return [
          _DisputeBanner(dispute: _dispute),
        ];
    }
  }

  // ── Pending start ──────────────────────────────────────────────────────────

  List<Widget> _buildPendingStartSection(
      BuildContext context, bool isClient) {
    final hasMilestones = _milestones.isNotEmpty;
    final allPending = hasMilestones &&
        _milestones.every((m) => m.isPendingApproval);

    if (isClient) {
      if (!hasMilestones) {
        return [
          _StatusBanner(
            icon: Icons.hourglass_empty,
            color: Colors.blue,
            title: 'Awaiting Milestone Plan',
            subtitle:
                'The freelancer is preparing the milestone plan for your review.',
          ),
        ];
      }
      if (allPending) {
        return [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.pending_actions, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Milestone Plan Ready for Review',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 15),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'The freelancer has proposed ${_milestones.length} milestone(s). '
                    'Review, then approve or reject the plan.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Review Milestone Plan'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MilestonePlanReviewPage(
                            project: _project!,
                            milestones: _milestones,
                          ),
                        ),
                      ).then((_) => _load()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      }
    } else {
      // Freelancer
      if (!hasMilestones) {
        return [
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.assignment, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Action Required: Propose Milestone Plan',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 15),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Define at least 2 milestones. Percentages must total 100%.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_task),
                      label: const Text('Propose Milestone Plan'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MilestonePlanPage(project: _project!),
                        ),
                      ).then((_) => _load()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      }
      if (allPending) {
        return [
          _StatusBanner(
            icon: Icons.hourglass_top,
            color: Colors.blue,
            title: 'Plan Submitted',
            subtitle: 'Awaiting client approval.',
          ),
        ];
      }
    }
    return [];
  }

  // ── In progress ────────────────────────────────────────────────────────────

  List<Widget> _buildInProgressSection(BuildContext context, bool isClient) {
    if (_milestones.isEmpty) {
      return [
        _StatusBanner(
          icon: Icons.task_outlined,
          color: Colors.grey,
          title: 'No milestones found.',
        ),
      ];
    }

    final allDone = ProjectService.allMilestonesCompleted(_milestones);
    final doneCount = _milestones.where((m) => m.isCompleted).length;

    return [
      // Section header
      Row(
        children: [
          const Text('Milestones',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$doneCount/${_milestones.length} done',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
      const SizedBox(height: 8),

      // Milestone cards
      ..._milestones.map(
        (m) => _MilestoneCard(
          milestone: m,
          isClient: isClient,
          onApprove: () => _approveFlow(m),
          onSubmit: () => _submitDeliverable(m),
          onReject: () => _rejectMilestone(m),
          onRevise: () async {
            final messenger = ScaffoldMessenger.of(context);
            final err = await AppState.instance.reviseMilestone(m);
            if (!mounted) return;
            if (err != null) {
              messenger.showSnackBar(
                SnackBar(content: Text(err), backgroundColor: Colors.red),
              );
            } else {
              messenger.showSnackBar(
                const SnackBar(content: Text('Revision started.')),
              );
            }
            await _load();
          },
          onRequestExtension: () => _requestExtension(m),
          onApproveExtension: () async {
            final messenger = ScaffoldMessenger.of(context);
            final err =
                await AppState.instance.approveMilestoneExtension(m);
            if (!mounted) return;
            if (err != null) {
              messenger.showSnackBar(
                SnackBar(content: Text(err), backgroundColor: Colors.red),
              );
            } else {
              messenger.showSnackBar(
                const SnackBar(content: Text('Extension approved.')),
              );
            }
            await _load();
          },
        ),
      ),

      // Complete project CTA (client, all milestones done)
      if (isClient && allDone) ...[
        const SizedBox(height: 8),
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.celebration, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Text('All milestones completed!',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 15)),
                ]),
                const SizedBox(height: 6),
                const Text(
                    'Sign and confirm to officially complete the project.'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.draw),
                    label: const Text('Sign & Complete Project'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectCompletionPage(
                          project: _project!,
                          milestones: _milestones,
                        ),
                      ),
                    ).then((ok) {
                      if (ok == true) {
                        AppState.instance.reloadProjects();
                        _load();
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  // ── Completed ──────────────────────────────────────────────────────────────

  List<Widget> _buildCompletedSection() {
    return [
      Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 26),
                SizedBox(width: 8),
                Text('Project Completed',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16)),
              ]),
              if (_project!.clientSignatureUrl != null) ...[
                const SizedBox(height: 6),
                const Row(children: [
                  Icon(Icons.draw, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Client signed off',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ],
            ],
          ),
        ),
      ),
      if (_milestones.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Milestones',
            style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._milestones.map(
          (m) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(m.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${m.percentage.toStringAsFixed(0)}%  ·  '
                  'RM ${m.paymentAmount.toStringAsFixed(2)}'),
              trailing: m.isPaid
                  ? const Icon(Icons.payments,
                      color: Colors.green, size: 20)
                  : null,
            ),
          ),
        ),
      ],
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectInfoCard extends StatelessWidget {
  const _ProjectInfoCard(
      {required this.project, required this.isClient});
  final ProjectItem project;
  final bool isClient;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = project.status.color;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.jobTitle ?? 'Project',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    project.status.displayName.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isClient)
              _InfoRow(Icons.code, 'Freelancer',
                  project.freelancerName ?? project.freelancerId)
            else
              _InfoRow(Icons.business, 'Client',
                  project.clientName ?? project.clientId),
            if (project.startDate != null)
              _InfoRow(
                  Icons.play_arrow, 'Started', _fmt(project.startDate!)),
            if (project.endDate != null)
              _InfoRow(Icons.flag, 'Deadline', _fmt(project.endDate!)),
            if (project.description != null &&
                project.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                project.description!,
                style: const TextStyle(
                    color: Colors.black87, fontSize: 13, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard(
      {required this.project, required this.milestones});
  final ProjectItem project;
  final List<MilestoneItem> milestones;

  @override
  Widget build(BuildContext context) {
    final budget = project.totalBudget ?? 0;
    final milestoneTotal =
        milestones.fold(0.0, (s, m) => s + m.paymentAmount);
    final displayTotal = milestoneTotal > 0 ? milestoneTotal : budget;
    final paid = milestones
        .where((m) => m.isCompleted)
        .fold(0.0, (s, m) => s + m.paymentAmount);

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BudgetColumn('Total', displayTotal),
                _BudgetColumn('Paid', paid,
                    color: Colors.green.shade700),
                _BudgetColumn('Remaining', displayTotal - paid,
                    color: Colors.orange.shade700),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value:
                    displayTotal > 0 ? (paid / displayTotal).clamp(0, 1) : 0,
                minHeight: 8,
                backgroundColor: Colors.white38,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayTotal > 0
                  ? '${(paid / displayTotal * 100).toStringAsFixed(0)}% paid'
                  : 'No milestones yet',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
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

/// Rich banner shown when a project is in [ProjectStatus.disputed] state.
/// Displays the dispute reason, status, description excerpt, and evidence count.
class _DisputeBanner extends StatelessWidget {
  const _DisputeBanner({required this.dispute});

  final DisputeRecord? dispute;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (dispute == null) {
      return Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.gavel, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dispute in Progress — Payment releases are paused.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final statusColor = switch (dispute!.status) {
      DisputeStatus.open        => Colors.orange,
      DisputeStatus.underReview => Colors.blue,
      DisputeStatus.resolved    => Colors.green,
      DisputeStatus.closed      => Colors.grey,
    };

    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Dispute Filed',
                    style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    dispute!.status.displayName,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reason: ${dispute!.reason.displayName}',
              style: tt.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              dispute!.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: Colors.orange.shade800),
            ),
            if (dispute!.hasEvidence) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.attach_file,
                      size: 13, color: Colors.orange.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${dispute!.evidenceUrls.length} evidence link(s) attached',
                    style: TextStyle(
                        fontSize: 12, color: Colors.orange.shade700),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '⏸ Payment releases are paused until the admin resolves this dispute.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.deepOrange,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 52, color: color.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestone,
    required this.isClient,
    required this.onApprove,
    required this.onSubmit,
    required this.onReject,
    required this.onRevise,
    required this.onRequestExtension,
    required this.onApproveExtension,
  });

  final MilestoneItem milestone;
  final bool isClient;
  final VoidCallback onApprove;
  final VoidCallback onSubmit;
  final VoidCallback onReject;
  final VoidCallback onRevise;
  final VoidCallback onRequestExtension;
  final VoidCallback onApproveExtension;

  Color _statusColor(MilestoneStatus s) => switch (s) {
        MilestoneStatus.completed => Colors.green,
        MilestoneStatus.submitted => Colors.blue,
        MilestoneStatus.inProgress => Colors.orange,
        MilestoneStatus.rejected => Colors.red,
        MilestoneStatus.approved => Colors.teal,
        MilestoneStatus.pendingApproval => Colors.grey,
      };

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final m = milestone;
    final statusColor = _statusColor(m.status);
    final isOverdue = m.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Text(
                    '${m.orderIndex}',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
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
                    m.status.name.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Description
            Text(m.description,
                style: const TextStyle(
                    color: Colors.black87, height: 1.4)),
            const SizedBox(height: 6),

            // ── Meta ───────────────────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_money,
                        size: 14, color: Colors.grey),
                    Text(
                      'RM ${m.paymentAmount.toStringAsFixed(0)} '
                      '(${m.percentage.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12,
                        color: isOverdue ? Colors.red : Colors.grey),
                    const SizedBox(width: 3),
                    Text(
                      _fmtDate(m.effectiveDeadline),
                      style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.grey,
                          fontSize: 12),
                    ),
                    if (isOverdue)
                      const Text(' OVERDUE',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    if (m.extensionApproved && m.extensionDays != null)
                      Text(' +${m.extensionDays}d',
                          style: const TextStyle(
                              color: Colors.teal, fontSize: 10)),
                  ],
                ),
              ],
            ),

            // Revision count
            if (m.revisionCount > 0) ...[
              const SizedBox(height: 4),
              Text('Revised ${m.revisionCount} time(s)',
                  style: const TextStyle(
                      color: Colors.orange, fontSize: 12)),
            ],

            // Rejection note
            if (m.isRejected && m.rejectionNote != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(m.rejectionNote!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // Deliverable URL
            if (m.deliverableUrl != null &&
                m.deliverableUrl!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(m.deliverableUrl!,
                          style: const TextStyle(
                              color: Colors.blue, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],

            // Extension request banner
            if (m.extensionRequestedAt != null && !m.extensionApproved) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Extension requested: ${m.extensionDays} day(s)',
                        style: const TextStyle(
                            color: Colors.amber, fontSize: 12),
                      ),
                    ),
                    if (isClient)
                      TextButton(
                        onPressed: onApproveExtension,
                        style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(60, 28)),
                        child: const Text('Approve',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ],

            // Payment status
            if (m.isPaid) ...[
              const SizedBox(height: 4),
              const Row(children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green),
                SizedBox(width: 4),
                Text('Payment released',
                    style:
                        TextStyle(color: Colors.green, fontSize: 12)),
              ]),
            ],

            // ── Action buttons ─────────────────────────────────────────
            if (!m.isCompleted) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Freelancer actions
                  if (!isClient) ...[
                    if (m.isInProgress) ...[
                      if (m.extensionRequestedAt == null ||
                          m.extensionApproved)
                        TextButton.icon(
                          icon: const Icon(Icons.more_time, size: 16),
                          label: const Text('Extension'),
                          onPressed: onRequestExtension,
                          style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        icon: const Icon(Icons.upload, size: 16),
                        label: const Text('Submit'),
                        onPressed: onSubmit,
                      ),
                    ],
                    if (m.isRejected)
                      FilledButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Revise'),
                        onPressed: onRevise,
                      ),
                  ],
                  // Client actions
                  if (isClient && m.isSubmitted) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red)),
                      onPressed: onReject,
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

// ─────────────────────────────────────────────────────────────────────────────
// Payment status banner — shown when a PaymentRecord exists for the project
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentStatusBanner extends StatelessWidget {
  const _PaymentStatusBanner({required this.payment});
  final PaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final color = payment.status.color;
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(payment.status.icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escrow: ${payment.status.displayName}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    'RM ${payment.remainingHeld.toStringAsFixed(2)} remaining · '
                    '${(payment.releaseProgress * 100).toStringAsFixed(0)}% released',
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nudge banner — shown when project is inProgress but no payment record exists
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentNudgeBanner extends StatelessWidget {
  const _PaymentNudgeBanner(
      {required this.project, required this.milestones});
  final ProjectItem project;
  final List<MilestoneItem> milestones;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Payment not yet processed. Complete checkout to hold '
                'funds in escrow.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckoutScreen(
                    project: project,
                    milestones: milestones,
                  ),
                ),
              ),
              child: const Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overdue warning banner — shown in-line above milestone cards
// ─────────────────────────────────────────────────────────────────────────────

class _OverdueWarningBanner extends StatelessWidget {
  const _OverdueWarningBanner({
    required this.milestone,
    required this.status,
    required this.isFreelancer,
    this.onRequestExtension,
  });

  final MilestoneItem milestone;
  final OverdueStatus status;
  final bool isFreelancer;
  final VoidCallback? onRequestExtension;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    final daysLeft = OverdueService.daysUntilDeadline(milestone);
    final label = OverdueService.deadlineLabel(milestone);
    final isTriggered = status == OverdueStatus.triggered;

    return Card(
      color: color.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(status.icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTriggered
                        ? 'Enforcement triggered — project cancelled'
                        : '${status.displayName}: "${milestone.title}"',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (!isTriggered) ...[
              const SizedBox(height: 6),
              Text(
                isFreelancer
                    ? daysLeft >= 0
                        ? 'Submit your deliverable or request an extension before the deadline.'
                        : 'Deadline passed! Submit or request an extension within 24 h to avoid auto-cancellation.'
                    : daysLeft >= 0
                        ? 'The freelancer has $label to deliver this milestone.'
                        : 'Deadline passed. The project will be auto-cancelled in '
                          '${24 + daysLeft * 24} hours if nothing is submitted.',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
            // Extension request button for freelancers
            if (isFreelancer &&
                !isTriggered &&
                milestone.extensionRequestedAt == null &&
                onRequestExtension != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.more_time, size: 16),
                  label: const Text('Request Extension'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color)),
                  onPressed: onRequestExtension,
                ),
              ),
            ],
            // Pending extension note
            if (milestone.extensionRequestedAt != null &&
                !milestone.extensionApproved)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.pending_outlined,
                        size: 14, color: Colors.blue.shade400),
                    const SizedBox(width: 4),
                    Text(
                      'Extension request pending client approval.',
                      style: TextStyle(
                          color: Colors.blue.shade400, fontSize: 12),
                    ),
                  ],
                ),
              ),
            // Overdue dashboard link
            if (!isTriggered)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style:
                      TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.overdueDashboard,
                  ),
                  child: const Text('View all overdue',
                      style: TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
