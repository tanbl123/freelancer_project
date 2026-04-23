import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../../jobs/models/job_post.dart';
import '../models/application_item.dart';
import 'apply_form_page.dart';

/// A read-only detail page shown when a **freelancer** taps one of their
/// own application cards.
///
/// Displays:
///  • The full job post content (image, title, client, details, description,
///    skills) — identical visual style to JobDetailScreen but without any
///    Apply / Message bottom bar.
///  • A "My Application" card showing the freelancer's proposal, proposed
///    budget, timeline and current status.
///  • Edit / Withdraw actions at the bottom — only when still pending.
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
  bool _withdrawing = false;

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

    setState(() => _withdrawing = true);
    await AppState.instance.updateApplicationStatus(
        _app.id, ApplicationStatus.withdrawn);
    if (!mounted) return;
    setState(() => _withdrawing = false);
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

    // Live client name.
    final clientName = AppState.instance.users
            .where((u) => u.uid == _post.clientId)
            .firstOrNull
            ?.displayName ??
        _post.clientName;

    return Scaffold(
      appBar: AppBar(title: const Text('My Application')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Cover image ─────────────────────────────────────────────────
          if (_post.coverImageUrl != null && _post.coverImageUrl!.isNotEmpty)
            _buildCoverImage(_post.coverImageUrl!),

          // ── Status chips ─────────────────────────────────────────────────
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(_post.category,
                    style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              ),
              if (_post.isLive)
                Chip(
                  label: const Text('Accepting Applications',
                      style: TextStyle(fontSize: 12)),
                  backgroundColor: colors.primaryContainer,
                  labelStyle:
                      TextStyle(color: colors.onPrimaryContainer),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),

          // ── Job title ────────────────────────────────────────────────────
          const SizedBox(height: 8),
          Text(_post.title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ── Client info ──────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colors.secondaryContainer,
                child: Text(
                  clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.secondary),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  if (_post.createdAt != null)
                    Text(
                      'Posted on ${DateFormat('d MMM y').format(_post.createdAt!)}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Project details card (price, deadline, duration, applicants) ─
          _JobDetailsCard(post: _post),
          const SizedBox(height: 20),

          // ── About this project ───────────────────────────────────────────
          _Section(
            title: 'About This Project',
            child: Text(_post.description,
                style: const TextStyle(height: 1.65, fontSize: 14)),
          ),
          const SizedBox(height: 16),

          // ── Skills required ──────────────────────────────────────────────
          if (_post.requiredSkills.isNotEmpty) ...[
            _Section(
              title: 'Skills Required',
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _post.requiredSkills
                    .map((s) => Chip(
                          label: Text(s,
                              style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── My Application card ──────────────────────────────────────────
          _Section(
            title: 'My Application',
            child: _MyApplicationCard(app: _app),
          ),
        ],
      ),

      // ── Bottom action bar — Edit / Withdraw (pending only) ─────────────
      bottomNavigationBar: isPending
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Edit button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      onPressed: _handleEdit,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12)),
                    ),
                    const SizedBox(width: 12),
                    // Withdraw button
                    Expanded(
                      child: FilledButton.icon(
                        icon: _withdrawing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.undo, size: 18),
                        label: const Text('Withdraw Application'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _withdrawing ? null : _handleWithdraw,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCoverImage(String url) {
    final isRemote = url.startsWith('http');
    final isLocal =
        url.isNotEmpty && !isRemote && File(url).existsSync();

    if (!isRemote && !isLocal) return const SizedBox.shrink();

    final image = isRemote
        ? Image.network(url,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink())
        : Image.file(File(url),
            width: double.infinity, height: 220, fit: BoxFit.cover);

    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _FullscreenImage(url: url),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
                width: double.infinity, height: 220, child: image),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fullscreen, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Tap to expand',
                    style:
                        TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Job details summary card (price, deadline, duration, applicants) ─────────

class _JobDetailsCard extends StatelessWidget {
  const _JobDetailsCard({required this.post});
  final JobPost post;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final daysLeft = post.daysUntilDeadline;

    final items = <_Item>[];

    if (post.budgetDisplay != null) {
      items.add(_Item(
        icon: Icons.payments_outlined,
        label: 'Price',
        value: post.budgetDisplay!,
        valueColor: Colors.green.shade700,
      ));
    }

    if (post.deadline != null) {
      final String ds;
      if (daysLeft == null) {
        ds = DateFormat('d MMM y').format(post.deadline!);
      } else if (daysLeft > 1) {
        ds = '$daysLeft days left';
      } else if (daysLeft == 1) {
        ds = '1 day left';
      } else if (daysLeft == 0) {
        ds = 'Closing today';
      } else {
        ds = 'Deadline passed';
      }
      items.add(_Item(
        icon: Icons.event_outlined,
        label: 'Application Deadline',
        value: ds,
        valueColor: (daysLeft ?? 99) <= 3 ? Colors.red : null,
      ));
    }

    if (post.projectDuration != null) {
      items.add(_Item(
        icon: Icons.timelapse_outlined,
        label: 'Project Duration',
        value: post.projectDuration!,
      ));
    }

    items.add(_Item(
      icon: Icons.people_outline,
      label: 'Applications',
      value: '${post.applicationCount} applied',
    ));

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(
                    width: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon,
                              size: 16, color: colors.secondary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 1),
                              Text(
                                item.value,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: item.valueColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _Item {
  const _Item({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
}

// ── Section header with accent bar ───────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: colors.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── My Application card ───────────────────────────────────────────────────────

class _MyApplicationCard extends StatelessWidget {
  const _MyApplicationCard({required this.app});
  final ApplicationItem app;

  Color _statusColor(ApplicationStatus s) => switch (s) {
        ApplicationStatus.pending => Colors.orange,
        ApplicationStatus.accepted => Colors.green,
        ApplicationStatus.rejected => Colors.red,
        ApplicationStatus.withdrawn => Colors.grey,
        ApplicationStatus.convertedToProject => Colors.blue,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(app.status);
    final submittedStr = app.createdAt != null
        ? DateFormat('d MMM y, h:mm a').format(app.createdAt!)
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    app.status.name.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (submittedStr != null) ...[
                  const Spacer(),
                  Text(submittedStr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Proposal
            Text('Proposal',
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(app.proposalMessage,
                style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ── Fullscreen image viewer ───────────────────────────────────────────────────

class _FullscreenImage extends StatelessWidget {
  const _FullscreenImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final isRemote = url.startsWith('http');
    final Widget image = isRemote
        ? Image.network(url, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image, size: 64)))
        : Image.file(File(url), fit: BoxFit.contain);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: image,
        ),
      ),
    );
  }
}
