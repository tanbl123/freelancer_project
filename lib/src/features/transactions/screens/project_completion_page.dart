import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/milestone_item.dart';
import '../models/project_item.dart';
import '../services/project_service.dart';
import 'signature_pad_page.dart';

/// Final client sign-off screen.
///
/// ## What this screen does
/// 1. **Pre-flight validation** — [ProjectService.canComplete] is evaluated
///    immediately.  If any milestones are not yet completed the screen shows a
///    blocking panel listing them; the "Sign" button is hidden until the issue
///    is resolved.
/// 2. **Milestone summary** — shows every milestone with its completion status,
///    payment amount and whether the payment has been released.
/// 3. **Signature capture** — tapping "Sign & Complete" pushes
///    [SignaturePadPage] configured to upload the PNG to Supabase Storage
///    (`project-signatures` bucket).  The returned URL (or offline fallback
///    local path) is passed directly to [AppState.completeProject].
/// 4. **Completion** — [AppState.completeProject] validates one final time
///    (re-fetches milestones), updates the project status to `completed`, and
///    writes the signature URL to `projects.client_signature_url`.
class ProjectCompletionPage extends StatefulWidget {
  const ProjectCompletionPage({
    super.key,
    required this.project,
    required this.milestones,
  });

  final ProjectItem project;
  final List<MilestoneItem> milestones;

  @override
  State<ProjectCompletionPage> createState() =>
      _ProjectCompletionPageState();
}

class _ProjectCompletionPageState extends State<ProjectCompletionPage> {
  bool _completing = false;

  /// Cached result of the synchronous guard — computed once in [initState].
  /// `null` means the project is ready to complete.
  late final String? _blockReason;

  /// Milestones that are preventing completion (status ≠ completed).
  late final List<MilestoneItem> _incomplete;

  @override
  void initState() {
    super.initState();
    _blockReason = ProjectService.canComplete(
        widget.project, widget.milestones);
    _incomplete = widget.milestones
        .where((m) => m.status != MilestoneStatus.completed)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ── Sign & complete flow ─────────────────────────────────────────────────

  Future<void> _signAndComplete() async {
    // Collect the client's digital signature.
    // SignaturePadPage returns:
    //   • a Supabase Storage public URL when the upload succeeds, OR
    //   • a local file path as an offline fallback.
    // Either value satisfies the "signature captured" requirement.
    final signatureUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SignaturePadPage(
          contextId: 'project_${widget.project.id}',
          promptText:
              'Sign below to confirm acceptance of all deliverables '
              'and authorise project completion.',
          legalText:
              'By signing, I confirm that all project milestones have been '
              'delivered to my satisfaction and I authorise the '
              'final completion of this project.',
          confirmLabel: 'Sign & Complete Project',
          // Trigger Supabase Storage upload so the URL stored in the DB is
          // a permanent, remotely-accessible HTTPS link rather than a local path.
          uploadConfig: SignatureUploadConfig(
            projectId: widget.project.id,
            userId: widget.project.clientId,
          ),
        ),
      ),
    );

    // User cancelled the signature pad.
    if (signatureUrl == null || !mounted) return;

    setState(() => _completing = true);

    // Re-fetch milestones from the DB for a final authoritative check before
    // mutating the project status.
    final latestMilestones =
        await AppState.instance.getMilestonesForProject(widget.project.id);

    final err = await AppState.instance.completeProject(
      widget.project,
      latestMilestones,
      signatureUrl, // now a remote URL (or local fallback)
    );

    if (!mounted) return;
    setState(() => _completing = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Project completed! Well done to both parties.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sorted = List<MilestoneItem>.from(widget.milestones)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final paidTotal = sorted.fold(0.0, (s, m) => s + m.paymentAmount);
    final budget = widget.project.totalBudget ?? paidTotal;
    final isReady = _blockReason == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Project')),
      body: Column(
        children: [
          // ── Summary header ────────────────────────────────────────────────
          _SummaryHeader(
            project: widget.project,
            milestones: sorted,
            paidTotal: paidTotal,
            budget: budget,
            fmt: _fmt,
          ),

          // ── Readiness check ───────────────────────────────────────────────
          // Use a promoted local so the null assertion is unnecessary.
          if (_blockReason case final reason?)
            _BlockedBanner(
              blockReason: reason,
              incomplete: _incomplete,
            ),

          // ── Milestone list ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Milestones',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: sorted.length,
              itemBuilder: (ctx, i) =>
                  _MilestoneRow(milestone: sorted[i]),
            ),
          ),

          // ── Action area ───────────────────────────────────────────────────
          _ActionBar(
            isReady: isReady,
            blockReason: _blockReason,
            completing: _completing,
            onSign: _signAndComplete,
          ),
        ],
      ),
    );
  }
}

// ── Summary header ────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.project,
    required this.milestones,
    required this.paidTotal,
    required this.budget,
    required this.fmt,
  });

  final ProjectItem project;
  final List<MilestoneItem> milestones;
  final double paidTotal;
  final double budget;
  final String Function(DateTime?) fmt;

  @override
  Widget build(BuildContext context) {
    final completed =
        milestones.where((m) => m.status == MilestoneStatus.completed).length;
    final allDone = completed == milestones.length;

    return Container(
      width: double.infinity,
      color: allDone ? Colors.green.shade50 : Colors.orange.shade50,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone
                    ? Icons.check_circle
                    : Icons.hourglass_bottom_rounded,
                color: allDone ? Colors.green : Colors.orange,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.jobTitle ?? 'Project',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      allDone
                          ? 'All milestones completed — ready to sign off.'
                          : '$completed / ${milestones.length} milestones completed.',
                      style: TextStyle(
                        color: allDone
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            children: [
              _Chip(
                  icon: Icons.task_alt,
                  label: '$completed / ${milestones.length}',
                  color: allDone ? Colors.green : Colors.orange),
              _Chip(
                  icon: Icons.attach_money,
                  label: 'RM ${paidTotal.toStringAsFixed(2)} paid',
                  color: allDone ? Colors.green : Colors.orange),
              if (project.endDate != null)
                _Chip(
                    icon: Icons.flag,
                    label: fmt(project.endDate),
                    color: allDone ? Colors.green : Colors.orange),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:
                    budget > 0 ? (paidTotal / budget).clamp(0, 1) : 0,
                minHeight: 6,
                backgroundColor: allDone
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                valueColor: AlwaysStoppedAnimation(
                    allDone ? Colors.green : Colors.orange),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Blocked banner ────────────────────────────────────────────────────────────

/// Shown when [ProjectService.canComplete] returns an error.
/// Lists every milestone that is not yet in the `completed` state.
class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({
    required this.blockReason,
    required this.incomplete,
  });

  final String blockReason;
  final List<MilestoneItem> incomplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block, size: 16, color: Colors.red.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  blockReason,
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          if (incomplete.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...incomplete.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      _iconForStatus(m.status),
                      size: 14,
                      color: m.status.color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${m.title}  ·  ${m.status.displayName}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The client may not sign off until every milestone above '
              'is completed and payment has been released.',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade600,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForStatus(MilestoneStatus s) {
    switch (s) {
      case MilestoneStatus.submitted:
        return Icons.pending_actions;
      case MilestoneStatus.inProgress:
        return Icons.timelapse;
      case MilestoneStatus.rejected:
        return Icons.cancel_outlined;
      case MilestoneStatus.pendingApproval:
        return Icons.hourglass_empty;
      default:
        return Icons.radio_button_unchecked;
    }
  }
}

// ── Milestone row ─────────────────────────────────────────────────────────────

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone});
  final MilestoneItem milestone;

  @override
  Widget build(BuildContext context) {
    final isComplete = milestone.status == MilestoneStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isComplete ? Colors.green.shade50 : Colors.grey.shade100,
          child: Icon(
            isComplete ? Icons.check : Icons.hourglass_empty,
            color: isComplete ? Colors.green : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          milestone.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${milestone.percentage.toStringAsFixed(0)}%  ·  '
          'RM ${milestone.paymentAmount.toStringAsFixed(2)}  ·  '
          '${milestone.status.displayName}',
          style: TextStyle(
            color: isComplete ? null : Colors.orange.shade700,
          ),
        ),
        trailing: isComplete
            ? Tooltip(
                message:
                    milestone.isPaid ? 'Payment released' : 'Payment pending',
                child: Icon(
                  milestone.isPaid ? Icons.payments : Icons.pending,
                  color:
                      milestone.isPaid ? Colors.green : Colors.orange,
                  size: 22,
                ),
              )
            : Tooltip(
                message: milestone.status.displayName,
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade600,
                  size: 22,
                ),
              ),
      ),
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isReady,
    required this.blockReason,
    required this.completing,
    required this.onSign,
  });

  final bool isReady;
  final String? blockReason;
  final bool completing;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    if (completing) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isReady) ...[
            // Explain why the button is absent.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Signature locked until all milestones are completed.',
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    isReady ? Colors.green : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.draw),
              label: Text(
                isReady
                    ? 'Sign & Complete Project'
                    : 'Signature Unavailable',
                style: const TextStyle(fontSize: 16),
              ),
              // Button is only active when all guards pass.
              onPressed: isReady ? onSign : null,
            ),
          ),
          if (isReady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This action is final and cannot be undone.',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Chip helper ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.9), fontSize: 13)),
      ],
    );
  }
}
