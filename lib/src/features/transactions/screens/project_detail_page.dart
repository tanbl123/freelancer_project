import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../services/stripe_service.dart';
import '../../../services/supabase_storage_service.dart';
import '../../../state/app_state.dart';
import '../../disputes/models/dispute_record.dart';
import '../../profile/models/profile_user.dart';
import '../../profile/screens/bank_details_sheet.dart';
import '../../overdue/services/overdue_service.dart';
import '../../ratings/models/review_item.dart';
import '../../ratings/screens/review_create_edit_screen.dart';
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
    AppState.instance.addListener(_onAppStateChange);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChange);
    super.dispose();
  }

  /// Called whenever AppState calls notifyListeners().
  ///
  /// • Status change (e.g. disputed → inProgress after admin resolves,
  ///   inProgress → cancelled) → full _load() so _dispute and _milestones
  ///   are also refreshed.
  /// • Minor change (name rename, etc.) → lightweight setState only.
  void _onAppStateChange() {
    if (!mounted) return;
    final updated = AppState.instance.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (updated == null) return;
    if (updated.status != _project?.status) {
      // Status changed — full reload so _dispute / _milestones stay in sync.
      _load();
    } else {
      // Always rebuild so the payment record (escrow balance) and
      // milestone statuses stay up to date after approvals.
      setState(() => _project = updated);
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final milestones =
        await AppState.instance.getMilestonesForProject(widget.projectId);

    // Always fetch directly from DB so status is always up-to-date
    // (avoids stale in-memory cache after cancel / dispute / completion)
    final project = await AppState.instance.getProjectById(widget.projectId)
        ?? AppState.instance.projects
            .where((p) => p.id == widget.projectId)
            .firstOrNull;

    // Always reload payment record from DB — the cached value goes stale
    // after milestone approvals (escrow banner would show wrong released %).
    await AppState.instance.loadPaymentForProject(widget.projectId);

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

  // ── Claim pending payouts (freelancer has account now, retry transfers) ──────

  Future<void> _claimPendingPayouts() async {
    // Mark all pending-payout milestones as "bank transfer initiated".
    // Stripe Connect is not available for MY-based platforms, so payouts are
    // processed manually via bank transfer to the freelancer's registered account.
    final pending = _milestones
        .where((m) =>
            m.isPaid && !(m.paymentToken?.startsWith('bt_') ?? false))
        .toList();
    if (pending.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    for (final m in pending) {
      // Mark as bank-transfer-initiated with a bt_ prefix token
      final btToken =
          'bt_${m.id.replaceAll('-', '').substring(0, 16)}';
      await Supabase.instance.client.from('milestones').update({
        'payment_token': btToken,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', m.id);
    }

    if (!mounted) return;
    await _load();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
            '${pending.length} payout${pending.length > 1 ? 's' : ''} queued for bank transfer within 3–5 business days.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ── Submit deliverable ─────────────────────────────────────────────────────

  Future<void> _submitDeliverable(MilestoneItem milestone) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SubmitDeliverableDialog(milestone: milestone),
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

  // ── Withdraw submitted deliverable (freelancer only) ──────────────────────

  Future<void> _withdrawMilestoneSubmission(MilestoneItem milestone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Submission?'),
        content: const Text(
          'This will remove your submitted deliverable and set the milestone '
          'back to In Progress. You can re-submit at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final err =
        await AppState.instance.withdrawMilestoneSubmission(milestone);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Submission withdrawn.')),
      );
    }
  }

  // ── Withdraw single-delivery submission (freelancer only) ─────────────────

  Future<void> _withdrawSingleDelivery(ProjectItem project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Submission?'),
        content: const Text(
          'This will remove your submitted deliverable. '
          'You can re-submit at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final err =
        await AppState.instance.withdrawSingleDeliverySubmission(project);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Submission withdrawn.')),
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
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CancelProjectDialog(),
    );
    if (reason == null || !mounted) return;

    final err =
        await AppState.instance.cancelProject(_project!, reason: reason);
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

    // Milestones approved but payout not yet initiated (token = po_ ref, not bt_/tr_)
    final pendingEarnings = !isClient
        ? _milestones
            .where((m) =>
                m.isPaid &&
                !(m.paymentToken?.startsWith('tr_') ?? false) &&
                !(m.paymentToken?.startsWith('bt_') ?? false))
            .fold(0.0, (sum, m) => sum + m.paymentAmount * 0.9)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_project!.jobTitle ?? 'Project Details'),
        actions: [
          // Payment status shortcut — freelancers only
          if (!isClient)
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
          if (_project!.isInProgress)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'dispute') _disputeProject();
              },
              itemBuilder: (_) => [
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
            _ProjectInfoCard(
              project: _project!,
              isClient: isClient,
              milestones: _milestones,
            ),
            const SizedBox(height: 10),
            _BudgetCard(project: _project!, milestones: _milestones, payment: paymentRecord),
            const SizedBox(height: 10),
            // ── Payment status banner — freelancers only ──────────────
            if (paymentRecord != null && !isClient)
              _PaymentStatusBanner(
                payment: paymentRecord,
                milestones: _milestones,
                project: _project!,
              ),
            // ── Payout banner (freelancer only) ───────────────────────
            // Always shown for freelancers:
            //   • No account registered  → amber "Set Up Now" prompt
            //   • Account registered     → green card with account info + Edit
            if (!isClient)
              _PayoutSetupBanner(
                user: user,
                pendingEarningsMyr: pendingEarnings,
              ),
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
            subtitle: _project!.cancellationReason != null
                ? 'Reason: ${_project!.cancellationReason}'
                : null,
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
    final project = _project!;
    final hasMilestones = _milestones.isNotEmpty;
    final allPending = hasMilestones &&
        _milestones.every((m) => m.isPendingApproval);

    // ── Single Delivery: chosen but awaiting client payment ──────────────────
    if (project.isSingleDelivery) {
      if (isClient) {
        return [_SingleDeliveryPayCard(
          project: project,
          onPayAndStart: () => _payAndStartSingleDelivery(project),
        )];
      } else {
        return [
          _StatusBanner(
            icon: Icons.hourglass_top,
            color: Colors.orange,
            title: 'Waiting for Client Payment',
            subtitle: 'You chose Single Delivery. The client needs to '
                'secure payment before you can start working.',
          ),
        ];
      }
    }

    if (isClient) {
      // ── Client: no plan yet ────────────────────────────────────────────────
      if (!hasMilestones) {
        return [
          _StatusBanner(
            icon: Icons.hourglass_empty,
            color: Colors.blue,
            title: 'Awaiting Delivery Plan',
            subtitle:
                'The freelancer is preparing their delivery plan for your review.',
          ),
        ];
      }
      // ── Client: milestone plan ready ───────────────────────────────────────
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
                    'Review, pay, and approve to get started.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Review & Pay'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MilestonePlanReviewPage(
                            project: project,
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
      // ── Freelancer: no plan chosen yet → show choice card ─────────────────
      if (!hasMilestones) {
        return [_DeliveryModeChoiceCard(
          project: project,
          onSingleDelivery: () async {
            // ── Confirmation dialog before locking in Single Delivery ─────
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Choose Single Delivery?'),
                content: const Text(
                  'You will submit all your work as one deliverable.\n\n'
                  'The client will pay upfront before you start, then '
                  'review and approve your final submission.\n\n'
                  'This cannot be changed once confirmed.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            // ─────────────────────────────────────────────────────────────
            if (!mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            final err = await AppState.instance.chooseSingleDelivery(project);
            if (!mounted) return;
            await _load();
            if (err != null) {
              messenger.showSnackBar(
                SnackBar(content: Text(err), backgroundColor: Colors.red),
              );
            } else {
              messenger.showSnackBar(const SnackBar(
                content: Text(
                    'Single Delivery selected. Waiting for client to pay and confirm.'),
              ));
            }
          },
          onMilestonePlan: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MilestonePlanPage(project: project),
            ),
          ).then((_) => _load()),
        )];
      }
      // ── Freelancer: milestone plan submitted, waiting for client ───────────
      if (allPending) {
        return [
          _StatusBanner(
            icon: Icons.hourglass_top,
            color: Colors.blue,
            title: 'Plan Submitted',
            subtitle: 'Awaiting client review and payment.',
          ),
        ];
      }
    }
    return [];
  }

  Future<void> _payAndStartSingleDelivery(ProjectItem project) async {
    // Client must pay first — same checkout screen used for milestone plans.
    // Milestones list is empty, so we pass [] and the checkout uses totalBudget.
    final paymentDone = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          project: project,
          milestones: const [],
        ),
      ),
    );
    if (paymentDone != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final err = await AppState.instance.approveSingleDeliveryStart(project);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Payment secured! Freelancer has been notified to start working.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  // ── In progress ────────────────────────────────────────────────────────────

  List<Widget> _buildInProgressSection(BuildContext context, bool isClient) {
    // ── Single Delivery mode ───────────────────────────────────────────────
    if (_project!.isSingleDelivery) {
      return _buildSingleDeliverySection(context, isClient);
    }

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
          isProjectCompleted: false, // project is inProgress here
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
          onWithdrawSubmission: () => _withdrawMilestoneSubmission(m),
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

  // ── Single delivery in-progress ───────────────────────────────────────────

  List<Widget> _buildSingleDeliverySection(
      BuildContext context, bool isClient) {
    final project = _project!;
    final isSubmitted = project.isSingleDeliverySubmitted;
    final wasRejected = project.isSingleDeliveryRejected;

    if (isClient) {
      if (!isSubmitted) {
        return [
          _StatusBanner(
            icon: Icons.hourglass_empty,
            color: Colors.blue,
            title: 'Awaiting Deliverable',
            subtitle: 'The freelancer is working on the deliverable. '
                'You will be notified when it is ready for review.',
          ),
        ];
      }
      // Client has a deliverable to review
      return [
        // ── Status header ──────────────────────────────────────────────────
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Deliverable Submitted — Review Required',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Submission content — white background so note/file card is visible
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.upload_file, size: 13, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              'Freelancer\'s Submission',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _DeliverableView(raw: project.singleDeliverableUrl!),

        // ── Action buttons ─────────────────────────────────────────────────
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red),
                icon: const Icon(Icons.thumb_down_outlined),
                label: const Text('Reject'),
                onPressed: () => _rejectSingleDelivery(project),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green),
                icon: const Icon(Icons.thumb_up),
                label: const Text('Approve & Pay'),
                onPressed: () => _approveSingleDeliveryFlow(project),
              ),
            ),
          ],
        ),
      ];
    } else {
      // Freelancer view
      if (isSubmitted) {
        return [
          _StatusBanner(
            icon: Icons.hourglass_top,
            color: Colors.blue,
            title: 'Deliverable Submitted',
            subtitle: 'Awaiting client review and approval.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.upload_file,
                  size: 13, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                'Your Submission',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700),
              ),
              const Spacer(),
              // Freelancer can withdraw while client hasn't acted yet.
              GestureDetector(
                onTap: () => _withdrawSingleDelivery(project),
                child: Tooltip(
                  message: 'Withdraw submission',
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _DeliverableView(raw: project.singleDeliverableUrl!),
        ];
      }
      if (wasRejected) {
        return [
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Deliverable Rejected',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 15)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Reason: ${project.singleRejectionNote ?? "—"}'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.upload),
                      label: const Text('Re-submit Deliverable'),
                      onPressed: () =>
                          _submitSingleDeliverableFlow(project),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      }
      // Not yet submitted
      return [
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.upload_file, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Action Required: Submit Your Deliverable',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 15),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Complete the work, then submit a link or description. '
                  'The client will review and release full payment upon approval.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Submit Deliverable'),
                    onPressed: () =>
                        _submitSingleDeliverableFlow(project),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }
  }

  Future<void> _submitSingleDeliverableFlow(ProjectItem project) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SingleDeliverableDialog(project: project),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final err =
        await AppState.instance.submitSingleDelivery(project, result);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Deliverable submitted for review.')));
    }
  }

  Future<void> _approveSingleDeliveryFlow(ProjectItem project) async {
    // Collect digital signature
    final signaturePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SignaturePadPage(
          contextId: project.id,
          promptText:
              'Sign to approve and release full payment for this project.',
        ),
      ),
    );
    if (signaturePath == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final err = await AppState.instance
        .approveSingleDelivery(project, signaturePath);
    if (!mounted) return;
    await AppState.instance.reloadProjects();
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Delivery approved! Payment released. Project completed.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _rejectSingleDelivery(ProjectItem project) async {
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
    final err = await AppState.instance.rejectSingleDelivery(project, result);
    if (!mounted) return;
    await _load();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Deliverable rejected. Freelancer will be notified.')));
    }
  }

  // ── Completed ──────────────────────────────────────────────────────────────

  List<Widget> _buildCompletedSection() {
    final user    = AppState.instance.currentUser;
    final project = _project!;
    final isClient = user?.uid == project.clientId;

    // Look up any existing review the current user wrote for this project.
    final myReview = AppState.instance.reviews
        .where((r) => r.reviewerId == user?.uid && r.projectId == project.id)
        .firstOrNull;

    // For the freelancer: find the review the client wrote about them.
    final clientReview = !isClient
        ? AppState.instance.reviews
            .where((r) =>
                r.reviewerId == project.clientId &&
                r.projectId == project.id)
            .firstOrNull
        : null;

    // Resolve the other party's name from the live users list so we always show
    // the current name even if the denormalized field on the project is stale.
    final otherUid  = isClient ? project.freelancerId : project.clientId;
    final otherUser = AppState.instance.users
        .where((u) => u.uid == otherUid)
        .firstOrNull;
    final otherName = otherUser?.displayName
        ?? (isClient
            ? (project.freelancerName ?? 'Freelancer')
            : (project.clientName ?? 'Client'));

    return [
      // ── Completion banner ──────────────────────────────────────────────
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
              if (project.clientSignatureUrl != null) ...[
                const SizedBox(height: 6),
                const Row(children: [
                  Icon(Icons.draw, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Client signed off',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ],
              if (project.isSingleDelivery) ...[
                const SizedBox(height: 6),
                const Row(children: [
                  Icon(Icons.bolt, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Single Delivery',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ],
            ],
          ),
        ),
      ),

      // ── Review section ────────────────────────────────────────────────
      // Client: full prompt + edit/delete controls.
      // Freelancer: read-only view of the client's review (if any).
      if (isClient) ...[
        const SizedBox(height: 12),
        if (myReview == null)
          _ReviewPromptCard(
            project: project,
            otherName: otherName,
            onReviewed: _load,
          )
        else if (myReview.isRemoved)
          const _ReviewRemovedCard()
        else
          _ReviewGivenCard(
            review: myReview,
            otherName: otherName,
            onDeleted: _load,
          ),
      ] else if (clientReview != null) ...[
        const SizedBox(height: 12),
        _ReviewReceivedCard(
          review: clientReview,
          reviewerName: project.clientName ?? 'Client',
        ),
      ],

      // ── Deliverable link (single-delivery) ────────────────────────────
      if (project.isSingleDelivery &&
          project.singleDeliverableUrl != null) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.upload_file, size: 13, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              'Submitted Deliverable',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _DeliverableView(raw: project.singleDeliverableUrl!),
      ],

      // ── Milestone list (milestone-mode) ───────────────────────────────
      // Use _MilestoneCard (same as the in-progress view) so clients and
      // freelancers can still see each milestone's submitted deliverable.
      // _MilestoneCard automatically hides all action buttons when
      // m.isCompleted is true, so no interactive controls appear here.
      if (!project.isSingleDelivery && _milestones.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Milestones',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._milestones.map(
          (m) => _MilestoneCard(
            milestone: m,
            isClient: isClient,
            isProjectCompleted: true, // view-only — no actions allowed
            onApprove: () {},
            onSubmit: () {},
            onReject: () {},
            onRevise: () {},
            onRequestExtension: () {},
            onApproveExtension: () {},
            onWithdrawSubmission: () {},
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
  const _ProjectInfoCard({
    required this.project,
    required this.isClient,
    required this.milestones,
  });
  final ProjectItem project;
  final bool isClient;
  final List<MilestoneItem> milestones;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = project.status.color;

    // Always resolve names from the live users list so the project card
    // reflects the current display name, not the stale denormalized copy.
    final allUsers   = AppState.instance.users;
    final freelancer = allUsers.where((u) => u.uid == project.freelancerId).firstOrNull;
    final client     = allUsers.where((u) => u.uid == project.clientId).firstOrNull;
    final freelancerLabel = freelancer?.displayName
        ?? project.freelancerName
        ?? project.freelancerId;
    final clientLabel = client?.displayName
        ?? project.clientName
        ?? project.clientId;

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
              _InfoRow(Icons.code, 'Freelancer', freelancerLabel)
            else
              _InfoRow(Icons.business, 'Client', clientLabel),
            if (project.startDate != null)
              _InfoRow(
                  Icons.play_arrow, 'Started', _fmt(project.startDate!)),
            // ── Deadline row ───────────────────────────────────────────
            // Single delivery → use the project end date directly.
            // Milestone plan  → use the last milestone's effective deadline
            //                   (accounts for approved extensions).
            if (project.isSingleDelivery) ...[
              if (project.endDate != null)
                _InfoRow(Icons.flag_outlined, 'Deadline', _fmt(project.endDate!)),
            ] else ...[
              if (milestones.isNotEmpty) ...[
                () {
                  final last = milestones.reduce((a, b) =>
                      a.orderIndex > b.orderIndex ? a : b);
                  return _InfoRow(
                    Icons.flag_outlined,
                    'Final Deadline',
                    _fmt(last.effectiveDeadline),
                  );
                }(),
              ] else if (project.endDate != null)
                _InfoRow(Icons.flag_outlined, 'Deadline', _fmt(project.endDate!)),
            ],
            if (project.isSingleDelivery || project.isInProgress || project.isCompleted)
              _InfoRow(Icons.bolt, 'Delivery', project.deliveryMode.displayName),
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
      {required this.project, required this.milestones, this.payment});
  final ProjectItem project;
  final List<MilestoneItem> milestones;
  final PaymentRecord? payment;

  @override
  Widget build(BuildContext context) {
    final budget = project.totalBudget ?? 0;
    final isSingle = project.isSingleDelivery;
    final milestoneTotal =
        milestones.fold(0.0, (s, m) => s + m.paymentAmount);
    final displayTotal = milestoneTotal > 0 ? milestoneTotal : budget;

    // For single delivery:
    // - Normally "paid" is full budget once project.isCompleted
    // - But when a dispute releases funds (project = cancelled, not completed),
    //   we must read payment.releasedAmount so the card matches the escrow card.
    final double paid;
    if (isSingle) {
      if (project.isCompleted) {
        paid = displayTotal;
      } else {
        // Use actual released amount (covers dispute resolution payouts)
        paid = (payment?.releasedAmount ?? 0.0).clamp(0.0, displayTotal);
      }
    } else {
      paid = milestones
          .where((m) => m.isCompleted)
          .fold(0.0, (s, m) => s + m.paymentAmount);
    }

    String progressLabel;
    if (displayTotal == 0) {
      progressLabel = 'No price set';
    } else if (isSingle) {
      if (project.isCompleted || paid >= displayTotal - 0.01) {
        progressLabel = 'Fully paid';
      } else if (paid > 0) {
        progressLabel = '${(paid / displayTotal * 100).toStringAsFixed(0)}% paid';
      } else {
        progressLabel = 'Pending approval';
      }
    } else {
      progressLabel =
          '${(paid / displayTotal * 100).toStringAsFixed(0)}% paid';
    }

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
            Text(progressLabel, style: const TextStyle(fontSize: 12)),
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

    final d = dispute!;
    final isSettled = d.status.isTerminal; // resolved or closed

    final statusColor = switch (d.status) {
      DisputeStatus.open        => Colors.orange,
      DisputeStatus.underReview => Colors.blue,
      DisputeStatus.resolved    => Colors.green,
      DisputeStatus.closed      => Colors.grey,
    };

    final cardBg     = isSettled ? Colors.green.shade50  : Colors.orange.shade50;
    final cardBorder = isSettled ? Colors.green.shade200  : Colors.orange.shade200;

    // Human-readable outcome footer text
    final String footerText;
    if (!isSettled) {
      footerText = '⏸ Payment releases are paused until the admin resolves this dispute.';
    } else {
      footerText = switch (d.resolution) {
        DisputeResolution.fullRefundToClient =>
            '✅ Admin decision: Full refund issued to the client.',
        DisputeResolution.fullReleaseToFreelancer =>
            '✅ Admin decision: Full payment released to the freelancer.',
        DisputeResolution.partialSplit =>
            '✅ Admin decision: Payment split between both parties.',
        DisputeResolution.noAction =>
            '✅ Admin decision: No payment changes. Dispute closed.',
        null =>
            '✅ Dispute has been resolved by the admin.',
      };
    }
    final footerColor = isSettled ? Colors.green.shade700 : Colors.deepOrange;

    return Card(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(
              children: [
                Icon(d.status.icon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSettled ? 'Dispute Resolved' : 'Dispute Filed',
                    style: TextStyle(
                        color: statusColor,
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
                    d.status.displayName,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Original dispute reason ───────────────────────────────────
            Text('Reason: ${d.reason.displayName}',
                style: tt.labelMedium),
            const SizedBox(height: 4),
            Text(
              d.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(
                  color: isSettled
                      ? Colors.green.shade800
                      : Colors.orange.shade800),
            ),

            // ── Evidence count ────────────────────────────────────────────
            if (d.hasEvidence) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.attach_file,
                      size: 13,
                      color: isSettled
                          ? Colors.green.shade600
                          : Colors.orange.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${d.evidenceUrls.length} evidence link(s) attached',
                    style: TextStyle(
                        fontSize: 12,
                        color: isSettled
                            ? Colors.green.shade700
                            : Colors.orange.shade700),
                  ),
                ],
              ),
            ],

            // ── Admin resolution block (only when settled) ────────────────
            if (isSettled && d.resolution != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Admin Decision: ${d.resolution!.displayName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green),
                        ),
                      ],
                    ),
                    if (d.adminNotes != null &&
                        d.adminNotes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        d.adminNotes!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800),
                      ),
                    ],
                    if (d.reviewedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reviewed on '
                        '${d.reviewedAt!.day.toString().padLeft(2, '0')}/'
                        '${d.reviewedAt!.month.toString().padLeft(2, '0')}/'
                        '${d.reviewedAt!.year}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade600),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── Footer status line ────────────────────────────────────────
            const SizedBox(height: 8),
            Text(
              footerText,
              style: TextStyle(
                  fontSize: 12,
                  color: footerColor,
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
    required this.isProjectCompleted,
    required this.onApprove,
    required this.onSubmit,
    required this.onReject,
    required this.onRevise,
    required this.onRequestExtension,
    required this.onApproveExtension,
    required this.onWithdrawSubmission,
  });

  final MilestoneItem milestone;
  final bool isClient;
  final bool isProjectCompleted;
  final VoidCallback onApprove;
  final VoidCallback onSubmit;
  final VoidCallback onReject;
  final VoidCallback onRevise;
  final VoidCallback onRequestExtension;
  final VoidCallback onApproveExtension;
  final VoidCallback onWithdrawSubmission;

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
                    // Show freelancer their net payout (after platform fee)
                    if (!isClient) ...[
                      const SizedBox(width: 8),
                      Text(
                        '→ You receive RM ${(m.paymentAmount * 0.9).toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
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

            // Deliverable submission
            if (m.deliverableUrl != null &&
                m.deliverableUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.upload_file,
                      size: 13,
                      color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Freelancer\'s Submission',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700),
                  ),
                  const Spacer(),
                  // Freelancer can withdraw a pending submission before
                  // the client approves or rejects it.
                  // Hidden once the project is completed (view-only mode).
                  if (!isClient && m.isSubmitted && !isProjectCompleted)
                    GestureDetector(
                      onTap: onWithdrawSubmission,
                      child: Tooltip(
                        message: 'Withdraw submission',
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _DeliverableView(raw: m.deliverableUrl!),
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

            // ── Action buttons — hidden for completed projects (view-only)
            if (!m.isCompleted && !isProjectCompleted) ...[
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
  const _PaymentStatusBanner({
    required this.payment,
    required this.milestones,
    required this.project,
  });
  final PaymentRecord payment;
  final List<MilestoneItem> milestones;
  final ProjectItem project;

  @override
  Widget build(BuildContext context) {
    // ── Derive released amount ────────────────────────────────────────────────
    // payment_records.released_amount can lag when the payout RPC fails silently.
    //
    // Milestone plan: sum completed milestone amounts as authoritative source.
    // Single delivery: once the project is completed the full amount is released
    //   (there are no milestone rows to sum, so we detect this case explicitly).
    final double effectiveReleased;
    if (project.isSingleDelivery && project.isCompleted) {
      // All funds released when a single-delivery project is marked complete.
      effectiveReleased = payment.totalAmount;
    } else {
      final milestoneReleased = milestones
          .where((m) => m.isCompleted)
          .fold(0.0, (s, m) => s + m.paymentAmount);
      // Take the higher of the two sources — never show LESS than what the DB says
      effectiveReleased = milestoneReleased > payment.releasedAmount
          ? milestoneReleased
          : payment.releasedAmount;
    }

    final effectiveRemaining =
        (payment.heldAmount - effectiveReleased - payment.refundedAmount)
            .clamp(0.0, payment.heldAmount);

    final effectiveProgress = payment.totalAmount > 0
        ? (effectiveReleased / payment.totalAmount).clamp(0.0, 1.0)
        : 0.0;

    // Derive a display status from effective values so the label/colour/icon
    // stay accurate even when the DB row is stale.
    final PaymentStatus displayStatus;
    if (effectiveReleased >= payment.totalAmount - 0.01 &&
        payment.totalAmount > 0) {
      displayStatus = PaymentStatus.fullyReleased;
    } else if (effectiveReleased > 0) {
      displayStatus = PaymentStatus.partiallyReleased;
    } else {
      displayStatus = payment.status;
    }

    final color = displayStatus.color;
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(displayStatus.icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escrow: ${displayStatus.displayName}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    'RM ${effectiveRemaining.toStringAsFixed(2)} remaining · '
                    '${(effectiveProgress * 100).toStringAsFixed(0)}% released',
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
// Payout banner — two states:
//   • No bank account  →  amber "Set Up Now" card  → opens BankDetailsSheet
//   • Account saved    →  green card showing account info + "Edit" button
// ─────────────────────────────────────────────────────────────────────────────

class _PayoutSetupBanner extends StatelessWidget {
  const _PayoutSetupBanner({
    required this.user,
    this.pendingEarningsMyr = 0.0,
  });

  /// The current freelancer — used to read/display bank account details.
  final ProfileUser user;

  /// Net earnings (after platform fee) awaiting bank transfer.
  final double pendingEarningsMyr;

  /// Masks all but the last 4 digits: "12345678" → "•••• 5678"
  static String _maskAccount(String number) {
    final trimmed = number.replaceAll(' ', '');
    if (trimmed.length <= 4) return trimmed;
    return '•••• ${trimmed.substring(trimmed.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = user.hasBankAccount;
    final amountStr = 'RM ${pendingEarningsMyr.toStringAsFixed(2)}';
    final hasPending = pendingEarningsMyr > 0;

    // ── Case B: bank account registered ────────────────────────────────────
    if (hasAccount) {
      return Card(
        color: Colors.green.shade50,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.green.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_balance,
                  color: Colors.green.shade700, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payout Account Registered ✓',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Bank name + masked account number
                    Text(
                      '${user.bankName ?? 'Bank'}  '
                      '${_maskAccount(user.bankAccountNumber ?? '')}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Holder name
                    if (user.bankAccountHolder != null)
                      Text(
                        user.bankAccountHolder!,
                        style: TextStyle(
                            color: Colors.green.shade600, fontSize: 12),
                      ),
                    if (hasPending) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$amountStr will be transferred within 3–5 business days.',
                        style: TextStyle(
                            color: Colors.green.shade700, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade400),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit Details'),
                        onPressed: () =>
                            BankDetailsSheet.show(context, user),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Case A: no account yet — prompt setup ───────────────────────────────
    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.account_balance_outlined,
                color: Colors.orange.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPending
                        ? '$amountStr is waiting for you!'
                        : 'Set up your payout account',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasPending
                        ? 'Your earnings are safely held on the platform. '
                          'Add your bank account details to receive them.'
                        : 'Add your bank account so earnings can be transferred '
                          'when a milestone is approved.',
                    style: TextStyle(
                        color: Colors.orange.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.account_balance_outlined,
                          size: 14),
                      label: const Text('Set Up Now'),
                      onPressed: () =>
                          BankDetailsSheet.show(context, user),
                    ),
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

// ── Submit Deliverable Dialog ──────────────────────────────────────────────────

/// Separator used to encode note + file URL in a single [MilestoneItem.deliverableUrl].
const _deliverableSep = '||FILE||';

/// Parses a raw [deliverableUrl] value into its note and file-URL components.
({String? note, String? fileUrl}) _parseDeliverable(String raw) {
  if (raw.contains(_deliverableSep)) {
    final parts = raw.split(_deliverableSep);
    return (
      note: parts[0].trim().isEmpty ? null : parts[0].trim(),
      fileUrl: parts.length > 1 && parts[1].trim().isNotEmpty
          ? parts[1].trim()
          : null,
    );
  }
  // Legacy: plain URL or plain description
  final isUrl = raw.startsWith('http');
  return (note: isUrl ? null : raw, fileUrl: isUrl ? raw : null);
}

class _SubmitDeliverableDialog extends StatefulWidget {
  const _SubmitDeliverableDialog({required this.milestone});
  final MilestoneItem milestone;

  @override
  State<_SubmitDeliverableDialog> createState() =>
      _SubmitDeliverableDialogState();
}

class _SubmitDeliverableDialogState extends State<_SubmitDeliverableDialog> {
  final _noteCtrl = TextEditingController();
  String? _pickedFilePath;
  String? _pickedFileName;
  bool _uploading = false;
  String? _noteError;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() {
      _pickedFilePath = file.path;
      _pickedFileName = file.name;
    });
  }

  void _clearFile() => setState(() {
        _pickedFilePath = null;
        _pickedFileName = null;
      });

  Future<void> _submit() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) {
      setState(() => _noteError = 'Please describe the work completed.');
      return;
    }
    setState(() {
      _noteError = null;
      _uploading = true;
    });

    String? fileUrl;
    if (_pickedFilePath != null) {
      final user = AppState.instance.currentUser;
      if (user != null) {
        fileUrl = await SupabaseStorageService.instance.uploadDeliverableFile(
          localPath: _pickedFilePath!,
          userId: user.uid,
          milestoneId: widget.milestone.id,
        );
      }
      if (fileUrl == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'File upload failed — deliverable saved without attachment.'),
              backgroundColor: Colors.orange),
        );
      }
    }

    final encoded = fileUrl != null ? '$note$_deliverableSep$fileUrl' : note;
    if (mounted) Navigator.pop(context, encoded);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Deliverable'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milestone: "${widget.milestone.title}"',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // ── Description (required) ─────────────────────────────────
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Work Description *',
                hintText: 'Explain what was completed, any decisions made, etc.',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                errorText: _noteError,
              ),
              maxLines: 4,
              autofocus: true,
              onChanged: (_) {
                if (_noteError != null) setState(() => _noteError = null);
              },
            ),
            const SizedBox(height: 16),

            // ── File attachment (optional) ─────────────────────────────
            const Text(
              'Proof / Attachment (optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            if (_pickedFileName != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(_fileIcon(_pickedFileName!),
                        size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pickedFileName!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearFile,
                      child: Icon(Icons.close,
                          size: 16, color: Colors.green.shade700),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Attach File'),
                onPressed: _pickFile,
              ),
            const SizedBox(height: 4),
            Text(
              'Supported: PDF, Word, Excel, images, zip, video, etc.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _uploading ? null : _submit,
          child: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

// ── Deliverable display ────────────────────────────────────────────────────────

class _DeliverableView extends StatelessWidget {
  const _DeliverableView({required this.raw});
  final String raw;

  Future<void> _openUrl(BuildContext context, String url) async {
    // For Office documents, wrap in Google Docs viewer so they open inline
    // instead of triggering a download dialog.
    final lower = url.toLowerCase();
    final isOfficeDoc = lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx');

    final viewerUrl = isOfficeDoc
        ? 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}'
        : url;

    final uri = Uri.tryParse(viewerUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open link. URL copied to clipboard.'),
              duration: Duration(seconds: 3)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (:note, :fileUrl) = _parseDeliverable(raw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description note
        if (note != null)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined,
                    size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note,
                    style: TextStyle(
                        color: Colors.blue.shade900, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // File attachment — tappable to open in browser
        if (fileUrl != null) ...[
          if (note != null) const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _openUrl(context, fileUrl),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(_fileIcon(fileUrl),
                        size: 16, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.basename(Uri.parse(fileUrl).path),
                            style: TextStyle(
                                color: Colors.purple.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Tap to open',
                            style: TextStyle(
                                color: Colors.purple.shade400, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    // Open icon
                    Icon(Icons.open_in_new,
                        size: 14, color: Colors.purple.shade600),
                    const SizedBox(width: 6),
                    // Copy URL
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await Clipboard.setData(
                            ClipboardData(text: fileUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Link copied to clipboard.'),
                                duration: Duration(seconds: 2)),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.copy,
                            size: 14, color: Colors.purple.shade500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

      ],
    );
  }
}

IconData _fileIcon(String nameOrUrl) {
  final ext = p.extension(nameOrUrl).toLowerCase().replaceFirst('.', '');
  switch (ext) {
    case 'pdf':            return Icons.picture_as_pdf_outlined;
    case 'doc':
    case 'docx':           return Icons.article_outlined;
    case 'xls':
    case 'xlsx':           return Icons.table_chart_outlined;
    case 'ppt':
    case 'pptx':           return Icons.slideshow_outlined;
    case 'zip':
    case 'rar':            return Icons.folder_zip_outlined;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':           return Icons.image_outlined;
    case 'mp4':
    case 'mov':
    case 'avi':            return Icons.video_file_outlined;
    default:               return Icons.attach_file;
  }
}

// ── Cancel Project Dialog ──────────────────────────────────────────────────────

class _CancelProjectDialog extends StatefulWidget {
  const _CancelProjectDialog();

  @override
  State<_CancelProjectDialog> createState() => _CancelProjectDialogState();
}

class _CancelProjectDialogState extends State<_CancelProjectDialog> {
  final _reasonCtrl = TextEditingController();
  String? _reasonError;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _reasonError = 'Please provide a reason for cancellation.');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This action cannot be undone. The project will be '
                    'cancelled and any held funds will be refunded.',
                    style: TextStyle(
                        color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason for Cancellation *',
              hintText: 'e.g. Scope changed, budget issues, etc.',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              errorText: _reasonError,
            ),
            onChanged: (_) {
              if (_reasonError != null) {
                setState(() => _reasonError = null);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep Project'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _confirm,
          child: const Text('Cancel Project'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery Mode Choice Card
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Single Delivery — client pay-and-start card (shown while pendingStart)
// ─────────────────────────────────────────────────────────────────────────────

class _SingleDeliveryPayCard extends StatelessWidget {
  const _SingleDeliveryPayCard({
    required this.project,
    required this.onPayAndStart,
  });

  final ProjectItem project;
  final VoidCallback onPayAndStart;

  @override
  Widget build(BuildContext context) {
    final budget = project.totalBudget;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.bolt, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Single Delivery — Payment Required',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 15),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'The freelancer will do everything in one submission. '
              'Secure the full payment in escrow now so they can start working.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            if (budget != null && budget > 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.lock, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'RM ${budget.toStringAsFixed(2)} will be held in escrow',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ]),
            ],
            const SizedBox(height: 14),
            // Payment-required notice
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(children: [
                Icon(Icons.lock_outline,
                    size: 14, color: Colors.amber.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Payment is required before the freelancer can start. '
                    'Funds release only after you approve their submission.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.amber.shade900),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                icon: const Icon(Icons.payment),
                label: Text(
                  budget != null && budget > 0
                      ? 'Pay RM ${budget.toStringAsFixed(2)} & Start'
                      : 'Pay & Start',
                ),
                onPressed: onPayAndStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery Mode Choice Card
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryModeChoiceCard extends StatelessWidget {
  const _DeliveryModeChoiceCard({
    required this.project,
    required this.onSingleDelivery,
    required this.onMilestonePlan,
  });

  final ProjectItem project;
  final VoidCallback onSingleDelivery;
  final VoidCallback onMilestonePlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.rule, color: Colors.deepPurple),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose Your Delivery Method',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.deepPurple),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            const Text(
              'How would you like to deliver the work for this project?',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // ── Single Delivery option ─────────────────────────────────────
            _DeliveryOptionTile(
              icon: Icons.bolt,
              color: Colors.orange,
              title: 'Single Delivery',
              description:
                  'Do all the work, submit one deliverable, get fully paid. '
                  'Best for small or simple projects.',
              buttonLabel: 'Choose Single Delivery',
              onTap: onSingleDelivery,
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // ── Milestone Plan option ──────────────────────────────────────
            _DeliveryOptionTile(
              icon: Icons.account_tree_outlined,
              color: Colors.blue,
              title: 'Milestone Plan',
              description:
                  'Break the project into stages. Get paid after each '
                  'milestone is approved. Best for long or complex projects.',
              buttonLabel: 'Create Milestone Plan',
              onTap: onMilestonePlan,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryOptionTile extends StatelessWidget {
  const _DeliveryOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14)),
        ]),
        const SizedBox(height: 4),
        Text(description,
            style:
                const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: color),
            onPressed: onTap,
            child: Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Deliverable Submit Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SingleDeliverableDialog extends StatefulWidget {
  const _SingleDeliverableDialog({required this.project});
  final ProjectItem project;

  @override
  State<_SingleDeliverableDialog> createState() =>
      _SingleDeliverableDialogState();
}

class _SingleDeliverableDialogState
    extends State<_SingleDeliverableDialog> {
  final _noteCtrl = TextEditingController();
  String? _pickedFilePath;
  String? _pickedFileName;
  bool _uploading = false;
  String? _noteError;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() {
      _pickedFilePath = file.path;
      _pickedFileName = file.name;
    });
  }

  void _clearFile() => setState(() {
        _pickedFilePath = null;
        _pickedFileName = null;
      });

  Future<void> _submit() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) {
      setState(() => _noteError = 'Please describe the work completed.');
      return;
    }
    setState(() {
      _noteError = null;
      _uploading = true;
    });

    String? fileUrl;
    if (_pickedFilePath != null) {
      final user = AppState.instance.currentUser;
      if (user != null) {
        fileUrl = await SupabaseStorageService.instance.uploadDeliverableFile(
          localPath: _pickedFilePath!,
          userId: user.uid,
          milestoneId: widget.project.id,
        );
      }
      if (fileUrl == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'File upload failed — deliverable saved without attachment.'),
              backgroundColor: Colors.orange),
        );
      }
    }

    final encoded = fileUrl != null ? '$note$_deliverableSep$fileUrl' : note;
    if (mounted) Navigator.pop(context, encoded);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.project.jobTitle ?? 'Project';
    return AlertDialog(
      title: const Text('Submit Deliverable'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project: "$title"',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // ── Description (required) ─────────────────────────────────
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Work Description *',
                hintText: 'Explain what was completed, any decisions made, etc.',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                errorText: _noteError,
              ),
              maxLines: 4,
              autofocus: true,
              onChanged: (_) {
                if (_noteError != null) setState(() => _noteError = null);
              },
            ),
            const SizedBox(height: 16),

            // ── File attachment (optional) ─────────────────────────────
            const Text(
              'Proof / Attachment (optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            if (_pickedFileName != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(_fileIcon(_pickedFileName!),
                        size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pickedFileName!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearFile,
                      child: Icon(Icons.close,
                          size: 16, color: Colors.green.shade700),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Attach File'),
                onPressed: _pickFile,
              ),
            const SizedBox(height: 4),
            Text(
              'Supported: PDF, Word, Excel, images, zip, video, etc.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _uploading ? null : _submit,
          child: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review widgets (shown in _buildCompletedSection)
// ─────────────────────────────────────────────────────────────────────────────

/// Read-only card shown to the freelancer when the client has left a review.
class _ReviewReceivedCard extends StatelessWidget {
  const _ReviewReceivedCard({
    required this.review,
    required this.reviewerName,
  });
  final ReviewItem review;
  final String reviewerName;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.star_rounded,
                    color: Colors.amber.shade600, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$reviewerName rated you',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Stars ──────────────────────────────────────────────────
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < review.stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: i < review.stars
                      ? Colors.amber.shade600
                      : Colors.grey.shade400,
                ),
              ),
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                review.comment,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when the current user's review was removed by an admin.
/// No further submission is allowed for this project.
class _ReviewRemovedCard extends StatelessWidget {
  const _ReviewRemovedCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.block_rounded,
                color: Colors.red.shade400, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Removed',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your review for this project was removed by our '
                    'moderation team for not meeting FreelanceHub\'s '
                    'community guidelines. No further reviews can be '
                    'submitted for this project.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade800,
                        height: 1.5),
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

/// Shown when the current user has NOT yet reviewed the other party.
/// Tapping "Rate Now" opens the full ReviewCreateEditScreen.
class _ReviewPromptCard extends StatelessWidget {
  const _ReviewPromptCard({
    required this.project,
    required this.otherName,
    required this.onReviewed,
  });

  final ProjectItem project;
  final String otherName;
  final VoidCallback onReviewed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'How was your experience?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Share your feedback about $otherName. Your review helps '
              'others make better decisions on FreelanceHub.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.star_outline_rounded, size: 18),
                label: Text('Rate $otherName'),
                onPressed: () async {
                  final done = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReviewCreateEditScreen(project: project),
                    ),
                  );
                  if (done == true) onReviewed();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the current user HAS already submitted a review.
/// Displays their stars and comment inline, with Edit and Delete actions.
class _ReviewGivenCard extends StatefulWidget {
  const _ReviewGivenCard({
    required this.review,
    required this.otherName,
    required this.onDeleted,
  });

  final ReviewItem review;
  final String otherName;
  /// Called after the review is successfully deleted so the parent can refresh
  /// and switch back to the [_ReviewPromptCard].
  final VoidCallback onDeleted;

  @override
  State<_ReviewGivenCard> createState() => _ReviewGivenCardState();
}

class _ReviewGivenCardState extends State<_ReviewGivenCard> {
  bool _deleting = false;

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Review?'),
        content: Text(
          'Your review of ${widget.otherName} will be permanently removed. '
          'You will be able to submit a new review afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final err = await AppState.instance.removeReview(widget.review);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Review removed. You can now submit a new one.'),
        ),
      );
      widget.onDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_deleting) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You reviewed ${widget.otherName}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                        fontSize: 13),
                  ),
                ),
                // Edit button
                TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.green.shade700),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReviewCreateEditScreen(review: widget.review),
                    ),
                  ),
                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                // Delete button
                TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.red.shade400),
                  onPressed: _handleDelete,
                  child: const Text('Delete', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Stars ────────────────────────────────────────────────────
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < widget.review.stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: i < widget.review.stars
                      ? Colors.amber.shade600
                      : Colors.grey.shade400,
                ),
              ),
            ),
            if (widget.review.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.review.comment,
                style: const TextStyle(fontSize: 13, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
