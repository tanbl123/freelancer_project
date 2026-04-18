import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_router.dart';
import '../../../shared/enums/job_status.dart';
import '../../../shared/enums/user_role.dart';
import '../../../state/app_state.dart';
import '../models/job_post.dart';
import '../widgets/job_badges.dart';

/// Full detail view for a single [JobPost].
///
/// - Freelancers see an "Apply Now" button (navigates to the Application Module).
/// - "Message Client" appears if [JobPost.allowPreEngagementChat] is true.
/// - Owners (clients) see Edit / Close / Cancel / Delete actions.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.post});
  final JobPost post;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late JobPost _post;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    // Fire-and-forget view count increment (non-critical).
    // Only track views from non-owners; the RPC handles atomic increment.
    final user = AppState.instance.currentUser;
    if (user?.uid != _post.clientId) {
      AppState.instance.recordJobPostView(_post.id);
    }
  }

  bool get _isOwner =>
      AppState.instance.currentUser?.uid == _post.clientId;

  bool get _isAdmin => AppState.instance.isAdmin;

  Future<void> _handleClose() async {
    final confirmed = await _confirm(
        'Close Job Post',
        'Close "${_post.title}"?\n\n'
            'The post will no longer appear in the job feed and '
            'will not accept new applications.');
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err =
        await AppState.instance.closeJobPost(_post.id, _post.clientId);
    if (!mounted) return;
    setState(() {
      _actionLoading = false;
      if (err == null) _post = _post.copyWith(status: JobStatus.closed);
    });
    _snack(err, 'Job post closed.');
  }

  Future<void> _handleCancel() async {
    final confirmed = await _confirm(
        'Cancel Job Post',
        'Cancel "${_post.title}"?\n\n'
            'This action marks the post as cancelled. '
            'You can delete it afterwards if needed.');
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err =
        await AppState.instance.cancelJobPost(_post.id, _post.clientId);
    if (!mounted) return;
    setState(() {
      _actionLoading = false;
      if (err == null) _post = _post.copyWith(status: JobStatus.cancelled);
    });
    _snack(err, 'Job post cancelled.');
  }

  Future<void> _handleReopen() async {
    final confirmed = await _confirm('Reopen Job Post',
        'Reopen "${_post.title}"? It will be visible in the job feed again.');
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err =
        await AppState.instance.reopenJobPost(_post.id, _post.clientId);
    if (!mounted) return;
    setState(() {
      _actionLoading = false;
      if (err == null) _post = _post.copyWith(status: JobStatus.open);
    });
    _snack(err, 'Job post reopened.');
  }

  Future<void> _handleDelete() async {
    final confirmed = await _confirm('Delete Job Post',
        'Permanently delete "${_post.title}"? This cannot be undone.');
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err =
        await AppState.instance.removeJobPost(_post.id, _post.clientId);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err == null && mounted) {
      Navigator.pop(context);
    } else {
      _snack(err, '');
    }
  }

  void _handleApply() {
    Navigator.pushNamed(context, AppRoutes.applicationApply,
        arguments: _post);
  }

  void _handlePreEngagementChat() {
    // TODO: Navigate to Chat Module once implemented.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat feature coming soon! '
            'Use the Apply button to submit your proposal.'),
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String? error, String success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? success)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isOpen = _post.status == JobStatus.open;
    final user = AppState.instance.currentUser;
    final isFreelancer = user?.role == UserRole.freelancer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (_isOwner || _isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    Navigator.pushNamed(context, AppRoutes.jobForm,
                        arguments: _post);
                    break;
                  case 'close':
                    _handleClose();
                    break;
                  case 'reopen':
                    _handleReopen();
                    break;
                  case 'cancel':
                    _handleCancel();
                    break;
                  case 'delete':
                    _handleDelete();
                    break;
                }
              },
              itemBuilder: (_) => [
                if (isOpen) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                        leading:
                            Icon(Icons.lock_outline, color: Colors.orange),
                        title: Text('Close Post',
                            style: TextStyle(color: Colors.orange)),
                        contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(
                        leading: Icon(Icons.cancel_outlined,
                            color: Colors.red),
                        title: Text('Cancel Post',
                            style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero),
                  ),
                ],
                if (!isOpen)
                  const PopupMenuItem(
                    value: 'reopen',
                    child: ListTile(
                        leading:
                            Icon(Icons.lock_open_outlined, color: Colors.green),
                        title: Text('Reopen',
                            style: TextStyle(color: Colors.green)),
                        contentPadding: EdgeInsets.zero),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Delete',
                          style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
        ],
      ),
      body: _actionLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cover image ─────────────────────────────────────────
                  if (_post.coverImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _post.coverImageUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  if (_post.coverImageUrl != null) const SizedBox(height: 16),

                  // ── Badges row ──────────────────────────────────────────
                  Row(
                    children: [
                      JobCategoryBadge(_post.category),
                      const SizedBox(width: 6),
                      JobStatusBadge(_post.status),
                      if (_post.isExpired && _post.status == JobStatus.open) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Deadline Passed',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Title ───────────────────────────────────────────────
                  Text(_post.title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),

                  // ── Client info ─────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Posted by ${_post.clientName}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                      if (_post.createdAt != null) ...[
                        const Text(' · ',
                            style: TextStyle(color: Colors.grey)),
                        Text(
                          DateFormat('d MMM y').format(_post.createdAt!),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Key info cards ──────────────────────────────────────
                  _InfoRow(
                    children: [
                      if (_post.budgetDisplay != null)
                        _InfoTile(
                          icon: Icons.attach_money,
                          label: 'Budget',
                          value: _post.budgetDisplay!,
                          valueColor: Colors.green.shade700,
                        ),
                      if (_post.deadline != null)
                        _InfoTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Deadline',
                          value: _post.daysUntilDeadline != null &&
                                  _post.daysUntilDeadline! > 0
                              ? '${_post.daysUntilDeadline} days left'
                              : DateFormat('d MMM y')
                                  .format(_post.deadline!),
                          valueColor: (_post.daysUntilDeadline ?? 99) <= 3
                              ? Colors.red
                              : null,
                        ),
                      _InfoTile(
                        icon: Icons.people_outline,
                        label: 'Applications',
                        value: '${_post.applicationCount}',
                      ),
                      if (_post.allowPreEngagementChat)
                        _InfoTile(
                          icon: Icons.chat_bubble_outline,
                          label: 'Chat',
                          value: 'Allowed',
                          valueColor: colors.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Description ─────────────────────────────────────────
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_post.description,
                      style: const TextStyle(height: 1.6, fontSize: 14)),
                  const SizedBox(height: 20),

                  // ── Required skills ─────────────────────────────────────
                  if (_post.requiredSkills.isNotEmpty) ...[
                    const Text('Required Skills',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _post.requiredSkills
                          .map((s) => Chip(
                                label: Text(s),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 80), // bottom padding for FAB
                ],
              ),
            ),

      // ── Bottom action bar ─────────────────────────────────────────────────
      bottomNavigationBar: !_actionLoading &&
              isFreelancer &&
              _post.isLive
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (_post.allowPreEngagementChat) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Message'),
                        onPressed: _handlePreEngagementChat,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Apply Now'),
                        onPressed: _handleApply,
                        style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

// ── Info tile widgets ──────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: children);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: valueColor),
          ),
        ],
      ),
    );
  }
}
