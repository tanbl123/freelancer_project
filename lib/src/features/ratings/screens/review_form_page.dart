import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../../transactions/models/project_item.dart';
import '../models/review_item.dart';
import 'freelancer_stats_page.dart';
import 'review_create_edit_screen.dart';

/// Review hub: Write · Received · Given  (+ Reported tab for admins).
///
/// - **Write** tab lists completed projects where the current user has not yet
///   left a review. Tapping one opens [ReviewCreateEditScreen].
/// - **Received** tab shows published reviews about the current user, with a
///   "Report" button on each card.
/// - **Given** tab shows reviews the current user has written, with Edit /
///   Delete actions.
/// - **Reported** tab (admin only) forwards to [AdminReviewListScreen].
class ReviewFormPage extends StatefulWidget {
  const ReviewFormPage({super.key});

  @override
  State<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<ReviewFormPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    final isAdmin = AppState.instance.currentUser?.role == UserRole.admin;
    _tab = TabController(length: isAdmin ? 4 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isAdmin = user?.role == UserRole.admin;
    final isFreelancer = user?.role == UserRole.freelancer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews & Ratings'),
        actions: [
          if (isFreelancer)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'My Stats',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        FreelancerStatsPage(freelancerId: user!.uid)),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            const Tab(text: 'Write'),
            const Tab(text: 'Received'),
            const Tab(text: 'Given'),
            if (isAdmin)
              ListenableBuilder(
                listenable: AppState.instance,
                builder: (_, __) {
                  final count = AppState.instance.reportedReviews.length;
                  return Tab(
                    child: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Text('Reported'),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          return TabBarView(
            controller: _tab,
            children: [
              _WriteTab(onRefresh: () => setState(() {})),
              _ReceivedTab(reviews: AppState.instance.myReceivedReviews),
              _GivenTab(reviews: AppState.instance.myGivenReviews),
              if (isAdmin)
                _ReportedTab(reviews: AppState.instance.reportedReviews),
            ],
          );
        },
      ),
    );
  }
}

// ── Write tab ─────────────────────────────────────────────────────────────────

class _WriteTab extends StatelessWidget {
  const _WriteTab({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final eligible = AppState.instance.eligibleReviewProjects;
    if (eligible.isEmpty) {
      return const _EmptyState(
        icon: Icons.rate_review_outlined,
        label: 'No eligible projects right now.\n'
            'Reviews can be submitted after a project is completed.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: eligible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _EligibleProjectCard(project: eligible[i]),
    );
  }
}

class _EligibleProjectCard extends StatelessWidget {
  const _EligibleProjectCard({required this.project});
  final ProjectItem project;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = AppState.instance.currentUser!;
    final revieweeName = project.clientId == user.uid
        ? (project.freelancerName ?? 'Freelancer')
        : (project.clientName ?? 'Client');

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            revieweeName.isNotEmpty ? revieweeName[0].toUpperCase() : '?',
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ),
        title: Text(project.jobTitle ?? 'Project',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Review $revieweeName',
            style: TextStyle(color: cs.primary)),
        trailing: FilledButton.tonal(
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ReviewCreateEditScreen(project: project)),
            );
            if (result == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Review submitted!')),
              );
            }
          },
          child: const Text('Review'),
        ),
      ),
    );
  }
}

// ── Received tab ──────────────────────────────────────────────────────────────

class _ReceivedTab extends StatelessWidget {
  const _ReceivedTab({required this.reviews});
  final List<ReviewItem> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const _EmptyState(
        icon: Icons.inbox_outlined,
        label: 'No reviews received yet.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reviews.length,
      itemBuilder: (_, i) =>
          _ReviewCard(review: reviews[i], mode: _CardMode.received),
    );
  }
}

// ── Given tab ─────────────────────────────────────────────────────────────────

class _GivenTab extends StatelessWidget {
  const _GivenTab({required this.reviews});
  final List<ReviewItem> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const _EmptyState(
        icon: Icons.edit_note_outlined,
        label: 'You have not written any reviews yet.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reviews.length,
      itemBuilder: (_, i) =>
          _ReviewCard(review: reviews[i], mode: _CardMode.given),
    );
  }
}

// ── Reported tab (admin) ──────────────────────────────────────────────────────

class _ReportedTab extends StatelessWidget {
  const _ReportedTab({required this.reviews});
  final List<ReviewItem> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline,
        label: 'No reported reviews pending moderation.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reviews.length,
      itemBuilder: (_, i) =>
          _ReviewCard(review: reviews[i], mode: _CardMode.admin),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

enum _CardMode { received, given, admin }

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.mode});
  final ReviewItem review;
  final _CardMode mode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final myId = AppState.instance.currentUser?.uid ?? '';

    final isRemoved = review.isRemoved;
    final isReported = review.isReported;

    // Resolve display names
    final reviewer = AppState.instance.users
        .where((u) => u.uid == review.reviewerId)
        .firstOrNull;
    final reviewee = AppState.instance.users
        .where((u) => u.uid == review.revieweeId)
        .firstOrNull;
    final reviewerName =
        review.reviewerName.isNotEmpty ? review.reviewerName : (reviewer?.displayName ?? 'User');
    final revieweeName = reviewee?.displayName ?? review.revieweeId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isRemoved
          ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Stars
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: isRemoved
                          ? Colors.grey
                          : Colors.amber,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${review.stars}/5',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRemoved ? Colors.grey : null)),
                const Spacer(),
                // Status badge
                _StatusBadge(status: review.status),
                const SizedBox(width: 8),
                // Date
                if (review.createdAt != null)
                  Text(
                    _fmtDate(review.createdAt!),
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Comment
            if (isRemoved)
              Text('This review has been removed.',
                  style: TextStyle(color: cs.outline, fontStyle: FontStyle.italic))
            else if (review.comment.isNotEmpty)
              Text(review.comment,
                  style: const TextStyle(height: 1.4))
            else
              Text('No comment.',
                  style: TextStyle(color: cs.outline)),
            const SizedBox(height: 8),

            // Sub-label
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: cs.outline),
                const SizedBox(width: 4),
                Text(
                  mode == _CardMode.received
                      ? 'From: $reviewerName'
                      : mode == _CardMode.given
                          ? 'For: $revieweeName'
                          : 'By: $reviewerName → $revieweeName',
                  style: TextStyle(color: cs.outline, fontSize: 12),
                ),
                if (isReported) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.flag, size: 13, color: Colors.orange.shade700),
                  Text(
                    ' ${review.reportedBy.length} report${review.reportedBy.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700),
                  ),
                ],
              ],
            ),

            // Action row
            const SizedBox(height: 6),
            _ActionRow(review: review, mode: mode, myId: myId),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

// ── Action row inside each card ───────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow(
      {required this.review, required this.mode, required this.myId});
  final ReviewItem review;
  final _CardMode mode;
  final String myId;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case _CardMode.received:
        if (review.isRemoved) return const SizedBox.shrink();
        final alreadyReported = review.isReportedBy(myId);
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: Icon(
                alreadyReported
                    ? Icons.flag
                    : Icons.flag_outlined,
                size: 16,
                color: alreadyReported ? Colors.orange : null),
            label: Text(
                alreadyReported ? 'Reported' : 'Report',
                style: TextStyle(
                    color: alreadyReported ? Colors.orange : null)),
            onPressed: alreadyReported
                ? null
                : () => _report(context),
          ),
        );

      case _CardMode.given:
        if (review.isRemoved) return const SizedBox.shrink();
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              onPressed: () => _edit(context),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Colors.red),
              label: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onPressed: () => _delete(context),
            ),
          ],
        );

      case _CardMode.admin:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!review.isRemoved)
              TextButton.icon(
                icon: const Icon(Icons.block, size: 16, color: Colors.red),
                label: const Text('Remove',
                    style: TextStyle(color: Colors.red)),
                onPressed: () => _adminRemove(context),
              ),
            if (review.isRemoved || review.isReported)
              TextButton.icon(
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Restore'),
                onPressed: () => _adminRestore(context),
              ),
          ],
        );
    }
  }

  Future<void> _report(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Report Review'),
        content: const Text(
            'Flag this review as inappropriate? An admin will review it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Report')),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    final err = await AppState.instance.reportReview(review);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(err ?? 'Review reported. Thank you.')));
    }
  }

  Future<void> _edit(BuildContext ctx) async {
    final result = await Navigator.push<bool>(
      ctx,
      MaterialPageRoute(
          builder: (_) => ReviewCreateEditScreen(review: review)),
    );
    if (result == true && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Review updated.')));
    }
  }

  Future<void> _delete(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    final err = await AppState.instance.removeReview(review);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(err ?? 'Review deleted.')));
    }
  }

  Future<void> _adminRemove(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Remove Review'),
        content: const Text(
            'Remove this review? It will be hidden from public view.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    await AppState.instance.adminRemoveReview(review);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Review removed.')));
    }
  }

  Future<void> _adminRestore(BuildContext ctx) async {
    await AppState.instance.adminRestoreReview(review);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Review restored and published.')));
    }
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == ReviewStatus.published) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.color),
          const SizedBox(width: 3),
          Text(status.displayName,
              style: TextStyle(
                  fontSize: 10,
                  color: status.color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.grey.shade500, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
