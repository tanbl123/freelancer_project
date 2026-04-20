import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../shared/enums/job_status.dart';
import '../../../shared/enums/user_role.dart';
import '../../../state/app_state.dart';
import '../models/job_post.dart';
import '../widgets/job_badges.dart';

/// Full detail view for a single [JobPost].
///
/// - Freelancers see "Contact" + "Apply Now" buttons.
/// - Owners (clients) and admins see Edit / Close / Cancel / Delete via overflow.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.post});
  final JobPost post;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late JobPost _post;
  bool _actionLoading = false;

  void _onStateChanged() {
    if (!mounted) return;

    // 1. Sync _post from the latest in-memory job post (picks up status changes,
    //    viewCount, and any server-side applicationCount increments).
    JobPost? updated;
    for (final p in [
      ...AppState.instance.jobPosts,
      ...AppState.instance.myJobPosts,
    ]) {
      if (p.id == _post.id) { updated = p; break; }
    }

    // 2. Optimistic local boost: if the current user just applied and the
    //    DB fetch hasn't returned yet, show at least 1 from their own record.
    //    For all other cases, refreshJobPost() fetches the real count from
    //    the applications table so every user sees the accurate number.
    final myApplications = AppState.instance.userApplications
        .where((a) => a.jobId == _post.id)
        .length;

    setState(() {
      final base = updated ?? _post;
      final bestCount = myApplications > base.applicationCount
          ? myApplications
          : base.applicationCount;
      _post = base.copyWith(applicationCount: bestCount);
    });
  }

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    AppState.instance.addListener(_onStateChanged);
    final user = AppState.instance.currentUser;
    if (user?.uid != _post.clientId) {
      AppState.instance.recordJobPostView(_post.id);
    }
    // Reload applications so the "Already Applied" button reflects real state.
    AppState.instance.reloadApplications();
    // Fetch the freshest counters (applicationCount, viewCount) from Supabase.
    // This ensures the client always sees the true number of applicants even
    // when applications were submitted from other devices.
    AppState.instance.refreshJobPost(_post.id);
  }

  bool get _isOwner =>
      AppState.instance.currentUser?.uid == _post.clientId;

  bool get _isAdmin => AppState.instance.isAdmin;

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  Future<void> _handleClose() async {
    final confirmed = await _confirm(
        'Stop Accepting Applications',
        'Close "${_post.title}"?\n\n'
            'The posting will be hidden from the job feed and '
            'no new applications will be accepted.');
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err =
        await AppState.instance.closeJobPost(_post.id, _post.clientId);
    if (!mounted) return;
    setState(() {
      _actionLoading = false;
      if (err == null) _post = _post.copyWith(status: JobStatus.closed);
    });
    _snack(err, 'Job posting closed.');
  }

  Future<void> _handleCancel() async {
    final confirmed = await _confirm(
        'Cancel Job Posting',
        'Cancel "${_post.title}"?\n\n'
            'This marks the posting as cancelled. '
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
    _snack(err, 'Job posting cancelled.');
  }

  Future<void> _handleReopen() async {
    final confirmed = await _confirm('Reopen Job Posting',
        'Reopen "${_post.title}"? It will be visible in the job feed again and accept new applications.');
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err =
        await AppState.instance.reopenJobPost(_post.id, _post.clientId);
    if (!mounted) return;
    setState(() {
      _actionLoading = false;
      if (err == null) _post = _post.copyWith(status: JobStatus.open);
    });
    _snack(err, 'Job posting reopened.');
  }

  Future<void> _handleDelete() async {
    final confirmed = await _confirm('Delete Job Posting',
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

  Future<void> _handleContact() async {
    final me = AppState.instance.currentUser;
    if (me == null || me.uid == _post.clientId) return;
    setState(() => _actionLoading = true);
    final room = await AppState.instance.openDirectChat(_post.clientId);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (room != null) {
      Navigator.pushNamed(context, AppRoutes.chatRoom, arguments: room);
    }
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
    final isClosed = _post.status == JobStatus.closed;
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
                        title: Text('Edit Posting'),
                        contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                        leading: Icon(Icons.lock_outline,
                            color: Colors.orange),
                        title: Text('Stop Accepting Applications',
                            style: TextStyle(color: Colors.orange)),
                        contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(
                        leading: Icon(Icons.cancel_outlined,
                            color: Colors.red),
                        title: Text('Cancel Posting',
                            style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero),
                  ),
                ],
                if (isClosed && !_post.isExpired)
                  const PopupMenuItem(
                    value: 'reopen',
                    child: ListTile(
                        leading: Icon(Icons.lock_open_outlined,
                            color: Colors.green),
                        title: Text('Reopen Posting',
                            style: TextStyle(color: Colors.green)),
                        contentPadding: EdgeInsets.zero),
                  ),
                if (isClosed && _post.isExpired)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(
                        leading: Icon(Icons.cancel_outlined,
                            color: Colors.red),
                        title: Text('Cancel Posting',
                            style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline,
                          color: Colors.red),
                      title: Text('Delete Posting',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cover image ─────────────────────────────────────
                  if (_post.coverImageUrl != null)
                    _buildCoverImage(_post.coverImageUrl!),

                  // ── Status banner (for freelancers) ─────────────────
                  if (isFreelancer) _JobStatusBanner(post: _post),

                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Badges row ──────────────────────────────
                        Row(
                          children: [
                            JobCategoryBadge(_post.category),
                            const SizedBox(width: 6),
                            JobStatusBadge(_post.status),
                            if (_post.isExpired &&
                                _post.status == JobStatus.open) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Text('Deadline Passed',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                        fontWeight:
                                            FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ── Title ───────────────────────────────────
                        Text(_post.title,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        // ── Client info row ─────────────────────────
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  colors.secondaryContainer,
                              child: Text(
                                _post.clientName.isNotEmpty
                                    ? _post.clientName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colors.secondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post.clientName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                  if (_post.createdAt != null)
                                    Text(
                                      'Posted on ${DateFormat('d MMM y').format(_post.createdAt!)}',
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Project details card ────────────────────
                        _ProjectDetailsCard(post: _post),
                        const SizedBox(height: 20),

                        // ── Description ─────────────────────────────
                        _SectionCard(
                          title: 'About This Project',
                          child: Text(_post.description,
                              style: const TextStyle(
                                  height: 1.65, fontSize: 14)),
                        ),
                        const SizedBox(height: 16),

                        // ── Required skills ─────────────────────────
                        if (_post.requiredSkills.isNotEmpty) ...[
                          _SectionCard(
                            title: 'Skills Required',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: _post.requiredSkills
                                  .map((s) => Chip(
                                        label: Text(s,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        visualDensity:
                                            VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      // ── Bottom action bar (freelancers only) ───────────────────────────────
      bottomNavigationBar: !_actionLoading && !_isOwner && isFreelancer
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
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline,
                          size: 18),
                      label: const Text('Message'),
                      onPressed: _handleContact,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12)),
                    ),
                    const SizedBox(width: 12),
                    if (_post.isLive)
                      Expanded(
                        child: _AlreadyAppliedButton(jobId: _post.id),
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
    final isLocal = url.isNotEmpty && !isRemote && File(url).existsSync();
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(0),
        bottomRight: Radius.circular(0),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 200,
        child: isRemote
            ? Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink())
            : isLocal
                ? Image.file(File(url), fit: BoxFit.cover)
                : const SizedBox.shrink(),
      ),
    );
  }
}

// ── Status banner ──────────────────────────────────────────────────────────

class _JobStatusBanner extends StatelessWidget {
  const _JobStatusBanner({required this.post});
  final JobPost post;

  @override
  Widget build(BuildContext context) {
    if (post.isLive) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.green.shade50,
        child: Row(
          children: [
            Icon(Icons.how_to_reg_outlined,
                size: 16, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text(
              'This project is accepting applications',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    if (post.status == JobStatus.closed) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.orange.shade50,
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(
              'This posting is no longer accepting applications',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    if (post.status == JobStatus.cancelled) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.red.shade50,
        child: Row(
          children: [
            Icon(Icons.cancel_outlined,
                size: 16, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Text(
              'This posting has been cancelled by the client',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Project details card ────────────────────────────────────────────────────

class _ProjectDetailsCard extends StatelessWidget {
  const _ProjectDetailsCard({required this.post});
  final JobPost post;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final daysLeft = post.daysUntilDeadline;
    final items = <_DetailItem>[];

    if (post.budgetDisplay != null) {
      items.add(_DetailItem(
        icon: Icons.payments_outlined,
        label: 'Budget',
        value: post.budgetDisplay!,
        valueColor: Colors.green.shade700,
      ));
    }

    if (post.deadline != null) {
      final String deadlineStr;
      if (daysLeft == null) {
        deadlineStr = DateFormat('d MMM y').format(post.deadline!);
      } else if (daysLeft > 1) {
        deadlineStr = '$daysLeft days left';
      } else if (daysLeft == 1) {
        deadlineStr = '1 day left';
      } else if (daysLeft == 0) {
        deadlineStr = 'Closing today';
      } else {
        deadlineStr = 'Deadline passed';
      }
      items.add(_DetailItem(
        icon: Icons.event_outlined,
        label: 'Application Deadline',
        value: deadlineStr,
        valueColor: (daysLeft ?? 99) <= 3 ? Colors.red : null,
      ));
    }

    if (post.projectDuration != null) {
      items.add(_DetailItem(
        icon: Icons.timelapse_outlined,
        label: 'Project Duration',
        value: post.projectDuration!,
      ));
    }

    items.add(_DetailItem(
      icon: Icons.people_outline,
      label: 'Applications',
      value: '${post.applicationCount} applied',
    ));

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: colors.outline.withValues(alpha: 0.2)),
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(item.label,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey)),
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

class _DetailItem {
  const _DetailItem({
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

// ── Section card ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
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
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── Apply / Applied button ─────────────────────────────────────────────────

/// Self-contained button that listens to [AppState] directly so it updates
/// immediately after applying — no parent rebuild required.
class _AlreadyAppliedButton extends StatefulWidget {
  const _AlreadyAppliedButton({required this.jobId});
  final String jobId;

  @override
  State<_AlreadyAppliedButton> createState() => _AlreadyAppliedButtonState();
}

class _AlreadyAppliedButtonState extends State<_AlreadyAppliedButton> {
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasApplied {
    final me = AppState.instance.currentUser;
    if (me == null) return false;
    return AppState.instance.userApplications.any((a) =>
        a.jobId == widget.jobId &&
        a.freelancerId == me.uid &&
        a.status != ApplicationStatus.withdrawn);
  }

  void _handleApply() {
    final post = AppState.instance.jobPosts
        .where((p) => p.id == widget.jobId)
        .firstOrNull;
    if (post == null) return;
    Navigator.pushNamed(context, AppRoutes.applicationApply, arguments: post);
  }

  @override
  Widget build(BuildContext context) {
    final applied = _hasApplied;
    if (applied) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
        label: const Text('Applied',
            style: TextStyle(
                color: Colors.green, fontWeight: FontWeight.w600)),
        onPressed: null, // disabled
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.green),
          disabledForegroundColor: Colors.green,
        ),
      );
    }
    return FilledButton.icon(
      icon: const Icon(Icons.send, size: 18),
      label: const Text('Apply Now'),
      onPressed: _handleApply,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
