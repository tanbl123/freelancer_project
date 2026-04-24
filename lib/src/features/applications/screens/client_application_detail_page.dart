import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';
import '../../jobs/models/job_post.dart';
import '../../jobs/screens/job_detail_screen.dart';
import '../models/application_item.dart';

/// Detail page shown when a **client** taps a received application card.
///
/// Clean 3-card layout:
///  1. Job Applied For — title, metadata chips, "View Job Details" button.
///  2. Applicant — avatar, name, "View Profile" button.
///  3. Proposal — status badge, submitted date, proposal text.
///  Bottom bar — Reject / Accept (pending only).
class ClientApplicationDetailPage extends StatefulWidget {
  const ClientApplicationDetailPage({
    super.key,
    required this.application,
  });

  final ApplicationItem application;

  @override
  State<ClientApplicationDetailPage> createState() =>
      _ClientApplicationDetailPageState();
}

class _ClientApplicationDetailPageState
    extends State<ClientApplicationDetailPage> {
  bool _acting = false;

  ApplicationItem get _app => widget.application;

  JobPost? get _post {
    for (final p in [
      ...AppState.instance.jobPosts,
      ...AppState.instance.myJobPosts,
    ]) {
      if (p.id == _app.jobId) return p;
    }
    return null;
  }

  Future<void> _handleAccept() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Application'),
        content: Text(
          'Accept ${_app.freelancerName}\'s proposal?\n\n'
          'All other applications for this job will be automatically '
          'rejected and a project will be created.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _acting = true);
    final err = await AppState.instance.acceptApplication(_app);
    if (!mounted) return;
    setState(() => _acting = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application accepted! Project created.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _handleReject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Application'),
        content: Text(
          'Reject ${_app.freelancerName}\'s application?\n\n'
          'They will be notified that their application was not selected.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _acting = true);
    await AppState.instance.updateApplicationStatus(
        _app.id, ApplicationStatus.rejected);
    if (!mounted) return;
    setState(() => _acting = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Application rejected.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPending = _app.status == ApplicationStatus.pending;
    final post = _post;

    final freelancerName = AppState.instance.users
            .where((u) => u.uid == _app.freelancerId)
            .firstOrNull
            ?.displayName ??
        _app.freelancerName;

    final statusColor = switch (_app.status) {
      ApplicationStatus.pending => Colors.orange,
      ApplicationStatus.accepted => Colors.green,
      ApplicationStatus.rejected => Colors.red,
      ApplicationStatus.withdrawn => Colors.grey,
      ApplicationStatus.convertedToProject => Colors.blue,
    };

    final submittedStr = _app.createdAt != null
        ? DateFormat('d MMM y, h:mm a').format(_app.createdAt!)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Application Detail')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Card 1: Job Applied For ────────────────────────────────────
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardLabel(icon: Icons.work_outline, label: 'Job Applied For', color: colors.primary),
                const SizedBox(height: 8),
                Text(
                  post?.title ?? 'Job ${_app.jobId.substring(0, 8)}…',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                if (post != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (post.budgetDisplay != null)
                        _MetaChip(icon: Icons.payments_outlined,
                            label: post.budgetDisplay!,
                            color: Colors.green.shade700),
                      _MetaChip(icon: Icons.folder_outlined, label: post.category),
                      if (post.projectDuration != null)
                        _MetaChip(icon: Icons.timelapse_outlined, label: post.projectDuration!),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View Job Details'),
                    onPressed: post == null
                        ? null
                        : () => Navigator.push(context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(
                                  post: post,
                                  hideApplyButton: true,
                                  readOnly: true,
                                ),
                              )),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Card 2: Applicant ──────────────────────────────────────────
          _DetailCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.secondaryContainer,
                  child: Text(
                    freelancerName.isNotEmpty ? freelancerName[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: colors.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(freelancerName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Freelancer',
                          style: TextStyle(fontSize: 12, color: colors.primary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline, size: 15),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context, AppRoutes.userProfile,
                    arguments: _app.freelancerId,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Card 3: Proposal ───────────────────────────────────────────
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusBadge(label: _app.status.name.toUpperCase(), color: statusColor),
                    if (submittedStr != null) ...[
                      const Spacer(),
                      Text(submittedStr,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _CardLabel(icon: Icons.description_outlined, label: 'Proposal'),
                const SizedBox(height: 6),
                Text(_app.proposalMessage,
                    style: const TextStyle(fontSize: 14, height: 1.6)),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: isPending
          ? _BottomBar(
              leftButton: OutlinedButton.icon(
                icon: _acting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _acting ? null : _handleReject,
              ),
              rightButton: FilledButton.icon(
                icon: _acting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label: const Text('Accept Application'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _acting ? null : _handleAccept,
              ),
            )
          : null,
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c,
            fontWeight: color != null ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.leftButton, required this.rightButton});
  final Widget leftButton;
  final Widget rightButton;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8, offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [leftButton, const SizedBox(width: 12), Expanded(child: rightButton)],
          ),
        ),
      );
}
