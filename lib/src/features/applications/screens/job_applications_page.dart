import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/application_item.dart';
import 'apply_form_page.dart';

class JobApplicationsPage extends StatelessWidget {
  const JobApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        automaticallyImplyLeading: false,
      ),
      body: const JobApplicationsBody(),
    );
  }
}

/// The scrollable body of the job-applications screen, extracted so it can
/// be embedded inside [RaDashboardScreen]'s TabBarView without a double-Scaffold.
class JobApplicationsBody extends StatefulWidget {
  const JobApplicationsBody({super.key});

  @override
  State<JobApplicationsBody> createState() => _JobApplicationsBodyState();
}

class _JobApplicationsBodyState extends State<JobApplicationsBody> {
  // true = Active (pending only), false = Closed (everything else)
  bool _showActive = true;

  // Status filter for the Closed tab; null = show all closed
  ApplicationStatus? _closedFilter;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChanged);
    AppState.instance.reloadApplications();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  /// Only PENDING applications need user action (Edit / Withdraw available).
  static bool _isPending(ApplicationStatus s) =>
      s == ApplicationStatus.pending;

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isFreelancer = user?.role == UserRole.freelancer;
    final allApps = AppState.instance.userApplications;

    // Active = pending only (user can still act on these)
    final activeApps =
        allApps.where((a) => _isPending(a.status)).toList();

    // Closed = accepted, converted, rejected, withdrawn
    final closedApps =
        allApps.where((a) => !_isPending(a.status)).toList();

    // Apply status sub-filter inside Closed tab
    final shownClosed = _closedFilter == null
        ? closedApps
        : closedApps.where((a) => a.status == _closedFilter).toList();

    final shown = _showActive ? activeApps : shownClosed;

    return RefreshIndicator(
      onRefresh: () => AppState.instance.reloadApplications(),
      child: Column(
        children: [
          // ── Active / Closed toggle ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Active',
                    count: activeApps.length,
                    selected: _showActive,
                    onTap: () => setState(() => _showActive = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TabButton(
                    label: 'Closed',
                    count: closedApps.length,
                    selected: !_showActive,
                    onTap: () => setState(() {
                      _showActive = false;
                      _closedFilter = null; // reset sub-filter on tab switch
                    }),
                  ),
                ),
              ],
            ),
          ),

          // ── Status sub-filter (Closed tab only) ───────────────────────────
          if (!_showActive && closedApps.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _StatusFilterChip(
                    label: 'All',
                    selected: _closedFilter == null,
                    onTap: () => setState(() => _closedFilter = null),
                  ),
                  _StatusFilterChip(
                    label: 'Accepted',
                    selected: _closedFilter == ApplicationStatus.accepted,
                    color: Colors.green,
                    onTap: () => setState(
                        () => _closedFilter = ApplicationStatus.accepted),
                  ),
                  _StatusFilterChip(
                    label: 'Converted',
                    selected:
                        _closedFilter == ApplicationStatus.convertedToProject,
                    color: Colors.blue,
                    onTap: () => setState(() =>
                        _closedFilter = ApplicationStatus.convertedToProject),
                  ),
                  _StatusFilterChip(
                    label: 'Rejected',
                    selected: _closedFilter == ApplicationStatus.rejected,
                    color: Colors.red,
                    onTap: () => setState(
                        () => _closedFilter = ApplicationStatus.rejected),
                  ),
                  _StatusFilterChip(
                    label: 'Withdrawn',
                    selected: _closedFilter == ApplicationStatus.withdrawn,
                    color: Colors.grey,
                    onTap: () => setState(
                        () => _closedFilter = ApplicationStatus.withdrawn),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showActive
                              ? Icons.description_outlined
                              : Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _showActive
                              ? (isFreelancer
                                  ? 'No pending applications.\nBrowse Jobs to find opportunities.'
                                  : 'No pending applications on your jobs yet.')
                              : (_closedFilter != null
                                  ? 'No ${_closedFilter!.name} applications.'
                                  : 'No closed applications yet.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: shown.length,
                    itemBuilder: (context, index) => _ApplicationCard(
                      item: shown[index],
                      currentUser: user,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Active / Closed tab button ────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.onPrimary.withValues(alpha: 0.25)
                      : cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? cs.onPrimary : cs.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Horizontal status filter chip (Closed tab) ───────────────────────────────

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = color ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.15)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? activeColor
                  : cs.outline.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? activeColor : cs.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.item, required this.currentUser});
  final ApplicationItem item;
  final dynamic currentUser;

  Color _statusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.withdrawn:
        return Colors.grey;
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.convertedToProject:
        return Colors.blue;
    }
  }

  /// Look up job title from the new JobPost list; fall back to truncated ID.
  String _jobTitle() {
    final posts = AppState.instance.jobPosts;
    try {
      return posts.firstWhere((p) => p.id == item.jobId).title;
    } catch (_) {
      // Not found — show a short version of the ID
      return 'Job ${item.jobId.length > 8 ? item.jobId.substring(0, 8) : item.jobId}…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final isClientView =
        user?.role == UserRole.client && item.clientId == user?.uid;
    final isFreelancerView =
        user?.role == UserRole.freelancer && item.freelancerId == user?.uid;
    final statusColor = _statusColor(item.status);

    // Live name lookup — avoids showing stale denormalised copy after rename.
    final freelancerName =
        AppState.instance.users
            .where((u) => u.uid == item.freelancerId)
            .firstOrNull
            ?.displayName ??
        item.freelancerName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/profile/view',
          arguments: item.freelancerId,
        ),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: applicant avatar + name + status badge ─────────
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(freelancerName[0].toUpperCase()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(freelancerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(
                        _jobTitle(),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
                    item.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Proposal text ──────────────────────────────────────────────
            Text(item.proposalMessage,
                style: const TextStyle(height: 1.4)),

            // ── Client actions (accept/reject) ─────────────────────────────
            if (isClientView && item.status == ApplicationStatus.pending) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red),
                    onPressed: () => _confirmReject(context),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    onPressed: () => _confirmAccept(context),
                  ),
                ],
              ),
            ],

            // ── Freelancer actions (edit/withdraw) ─────────────────────────
            if (isFreelancerView &&
                item.status == ApplicationStatus.pending) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApplyFormPage(existing: item),
                      ),
                    ).then((_) => AppState.instance.reloadApplications()),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Withdraw'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.orange),
                    onPressed: () {
                      AppState.instance.updateApplicationStatus(
                          item.id, ApplicationStatus.withdrawn);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Application withdrawn.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _confirmReject(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Application'),
        content: Text(
            'Reject ${item.freelancerName}\'s application?\n\n'
            'They will be notified that their application was not selected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              AppState.instance.updateApplicationStatus(
                  item.id, ApplicationStatus.rejected);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application rejected.')),
              );
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _confirmAccept(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Application'),
        content: Text(
            'Accept ${item.freelancerName}\'s proposal?\n\nAll other applications for this job will be automatically rejected and a project will be created.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await AppState.instance.acceptApplication(item);
              if (context.mounted) {
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(err), backgroundColor: Colors.red),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Application accepted! Project created.')),
                  );
                }
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
