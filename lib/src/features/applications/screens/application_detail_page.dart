import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';
import '../../jobs/models/job_post.dart';
import '../../jobs/screens/job_detail_screen.dart';
import '../models/application_item.dart';
import 'apply_form_page.dart';

/// Detail page shown when a **freelancer** taps one of their own application cards.
///
/// Clean 2-card layout:
///  1. Job Applied For — title, metadata chips, "View Job Details" button.
///  2. My Application — status badge, submitted date, proposal text.
///  Bottom bar — Edit / Withdraw (pending only).
class ApplicationDetailPage extends StatefulWidget {
  const ApplicationDetailPage({
    super.key,
    required this.application,
    required this.post,
  });

  final ApplicationItem application;
  final JobPost post;

  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  bool _acting = false;

  ApplicationItem get _app => widget.application;
  JobPost get _post => widget.post;

  Future<void> _handleWithdraw() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Withdraw Application'),
        content: const Text(
            'Are you sure you want to withdraw this application?\n\n'
            'The client will no longer see your proposal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _acting = true);
    await AppState.instance.updateApplicationStatus(
        _app.id, ApplicationStatus.withdrawn);
    if (!mounted) return;
    setState(() => _acting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application withdrawn.')),
    );
    Navigator.pop(context);
  }

  void _handleEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplyFormPage(existing: _app),
      ),
    ).then((_) => AppState.instance.reloadApplications());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPending = _app.status == ApplicationStatus.pending;

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

    final clientName = AppState.instance.users
            .where((u) => u.uid == _app.clientId)
            .firstOrNull
            ?.displayName ??
        _app.clientId;

    return Scaffold(
      appBar: AppBar(title: const Text('My Application')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Card 1: Job Applied For ────────────────────────────────────
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardLabel(
                    icon: Icons.work_outline,
                    label: 'Job Applied For',
                    color: colors.primary),
                const SizedBox(height: 8),
                Text(
                  _post.title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  children: [
                    if (_post.budgetDisplay != null)
                      _MetaChip(
                          icon: Icons.payments_outlined,
                          label: _post.budgetDisplay!,
                          color: Colors.green.shade700),
                    _MetaChip(
                        icon: Icons.folder_outlined, label: _post.category),
                    if (_post.projectDuration != null)
                      _MetaChip(
                          icon: Icons.timelapse_outlined,
                          label: _post.projectDuration!),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View Job Details'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(
                          post: _post,
                          hideApplyButton: true,
                          readOnly: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Card 2: Client ─────────────────────────────────────────────
          _DetailCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.secondaryContainer,
                  child: Text(
                    clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Client',
                          style:
                              TextStyle(fontSize: 12, color: colors.primary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline, size: 15),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.userProfile,
                    arguments: _app.clientId,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Card 3: My Application ─────────────────────────────────────
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusBadge(
                        label: _app.status.name.toUpperCase(),
                        color: statusColor),
                    if (submittedStr != null) ...[
                      const Spacer(),
                      Text(submittedStr,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _CardLabel(
                    icon: Icons.description_outlined, label: 'My Proposal'),
                const SizedBox(height: 6),
                Text(_app.proposalMessage,
                    style: const TextStyle(fontSize: 14, height: 1.6)),
              ],
            ),
          ),
        ],
      ),

      // ── Bottom action bar — Edit / Withdraw (pending only) ─────────────
      bottomNavigationBar: isPending
          ? _BottomBar(
              leftButton: OutlinedButton.icon(
                icon: _acting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.undo, size: 18),
                label: const Text('Withdraw'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                onPressed: _acting ? null : _handleWithdraw,
              ),
              rightButton: FilledButton.icon(
                icon: _acting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Application'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _acting ? null : _handleEdit,
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
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: c,
                fontWeight: FontWeight.w600)),
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
    final c = color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: c,
                fontWeight:
                    color != null ? FontWeight.w600 : FontWeight.normal)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.leftButton, required this.rightButton});
  final Widget leftButton;
  final Widget rightButton;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              leftButton,
              const SizedBox(width: 12),
              Expanded(child: rightButton),
            ],
          ),
        ),
      );
}
