import 'package:flutter/material.dart';

import '../../../../shared/enums/review_status.dart';
import '../../../../state/app_state.dart';
import '../../../../routing/app_router.dart';
import '../../models/review_item.dart';

/// Admin moderation screen for reviews.
///
/// Two tabs:
/// - **Reported** — reviews flagged by users, awaiting a decision.
/// - **All Reviews** — every review in the system with full status visibility.
///
/// Actions:
/// - **Remove** → sets status = `removed`, hides from public, recalculates stats.
/// - **Restore** → sets status = `published`, visible again.
class AdminReviewListScreen extends StatefulWidget {
  const AdminReviewListScreen({super.key});

  @override
  State<AdminReviewListScreen> createState() =>
      _AdminReviewListScreenState();
}

class _AdminReviewListScreenState extends State<AdminReviewListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 2, vsync: this);
  bool _loadingAll = true;
  List<ReviewItem> _allReviews = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await AppState.instance.loadReportedReviews();
    final all = await AppState.instance.reviewService.getAll();
    if (mounted) {
      setState(() {
        _allReviews = all;
        _loadingAll = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loadingAll = true);
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar row with inline refresh button
        Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tab,
                tabs: [
                  ListenableBuilder(
                    listenable: AppState.instance,
                    builder: (_, __) {
                      final n = AppState.instance.reportedReviews.length;
                      return Tab(
                        child: Badge(
                          isLabelVisible: n > 0,
                          label: Text('$n'),
                          child: const Text('Reported'),
                        ),
                      );
                    },
                  ),
                  const Tab(text: 'All Reviews'),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _refresh,
            ),
          ],
        ),
        Expanded(
          child: _loadingAll
              ? const Center(child: CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: AppState.instance,
                  builder: (_, __) => TabBarView(
                    controller: _tab,
                    children: [
                      _ReviewList(
                        reviews: AppState.instance.reportedReviews,
                        emptyLabel: 'No reported reviews. All clear! ✅',
                        emptyIcon: Icons.check_circle_outline,
                      ),
                      _ReviewList(
                        reviews: _allReviews,
                        emptyLabel: 'No reviews in the system yet.',
                        emptyIcon: Icons.rate_review_outlined,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Review list ───────────────────────────────────────────────────────────────

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.reviews,
    required this.emptyLabel,
    required this.emptyIcon,
  });
  final List<ReviewItem> reviews;
  final String emptyLabel;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyLabel,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: reviews.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _AdminReviewCard(review: reviews[i]),
    );
  }
}

// ── Admin review card ─────────────────────────────────────────────────────────

class _AdminReviewCard extends StatelessWidget {
  const _AdminReviewCard({required this.review});
  final ReviewItem review;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = review.status;

    final reviewer = AppState.instance.users
        .where((u) => u.uid == review.reviewerId)
        .firstOrNull;
    final reviewee = AppState.instance.users
        .where((u) => u.uid == review.revieweeId)
        .firstOrNull;
    final reviewerName =
        review.reviewerName.isNotEmpty ? review.reviewerName : (reviewer?.displayName ?? review.reviewerId);
    final revieweeName = reviewee?.displayName ?? review.revieweeId;

    final bgColor = switch (status) {
      ReviewStatus.reported =>
        Colors.orange.shade50,
      ReviewStatus.removed =>
        Colors.red.shade50,
      ReviewStatus.published => null,
    };

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: stars + status + date
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: status == ReviewStatus.removed
                        ? Colors.grey
                        : Colors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatusChip(status: status),
              const Spacer(),
              if (review.createdAt != null)
                Text(
                  _fmtDate(review.createdAt!),
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Comment
          if (review.comment.isNotEmpty)
            Text(
              review.comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  height: 1.4,
                  color: status == ReviewStatus.removed
                      ? Colors.grey
                      : null),
            )
          else
            Text('No comment.',
                style: TextStyle(color: cs.outline, fontSize: 13)),
          const SizedBox(height: 6),

          // Parties
          Text(
            'By: $reviewerName  →  For: $revieweeName',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),

          // Report count
          if (review.reportedBy.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.flag, size: 13,
                    color: Colors.orange.shade700),
                const SizedBox(width: 3),
                Text(
                  'Reported by ${review.reportedBy.length} user(s)',
                  style: TextStyle(
                      fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ],

          // User profile link
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.person_outline, size: 14),
                label: const Text('View reviewer'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminUserDetail,
                  arguments: {
                    'userId': review.reviewerId,
                    'showActions': false,
                  },
                ),
              ),
            ],
          ),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!review.isRemoved)
                TextButton.icon(
                  icon: const Icon(Icons.block,
                      size: 16, color: Colors.red),
                  label: const Text('Remove',
                      style: TextStyle(color: Colors.red)),
                  onPressed: () => _remove(context),
                ),
              if (review.isRemoved || review.isReported)
                TextButton.icon(
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Restore'),
                  onPressed: () => _restore(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Remove Review'),
        content:
            const Text('Remove this review? It will be hidden from all users.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    await AppState.instance.adminRemoveReview(review);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(const SnackBar(content: Text('Review removed.')));
    }
  }

  Future<void> _restore(BuildContext ctx) async {
    await AppState.instance.adminRestoreReview(review);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Review restored and published.')));
    }
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
