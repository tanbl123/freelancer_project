import 'package:flutter/material.dart';

import '../../../../shared/enums/review_status.dart';
import '../../../../state/app_state.dart';
import '../../../../routing/app_router.dart';
import '../../models/review_item.dart';

/// Admin moderation screen — shows every review in the system.
///
/// The admin can **Remove** any published review that violates community
/// guidelines.  Once removed the reviewer can no longer re-submit for that
/// project.  A removed review can be **Restored** if the admin made a mistake.
class AdminReviewListScreen extends StatefulWidget {
  const AdminReviewListScreen({super.key});

  @override
  State<AdminReviewListScreen> createState() =>
      _AdminReviewListScreenState();
}

class _AdminReviewListScreenState extends State<AdminReviewListScreen> {
  bool _loading = true;
  List<ReviewItem> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await AppState.instance.reviewService.getAll();
    if (mounted) {
      setState(() {
        _reviews = all;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row with refresh button
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 0, 8),
              child: Text(
                'All Reviews',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reviews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review_outlined,
                              size: 56,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No reviews in the system yet.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: _reviews.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) =>
                          _AdminReviewCard(review: _reviews[i], onChanged: _load),
                    ),
        ),
      ],
    );
  }
}

// ── Admin review card ─────────────────────────────────────────────────────────

class _AdminReviewCard extends StatelessWidget {
  const _AdminReviewCard({required this.review, required this.onChanged});
  final ReviewItem review;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRemoved = review.isRemoved;

    // Resolve live names from the users cache
    final reviewer = AppState.instance.users
        .where((u) => u.uid == review.reviewerId)
        .firstOrNull;
    final reviewee = AppState.instance.users
        .where((u) => u.uid == review.revieweeId)
        .firstOrNull;
    final reviewerName = reviewer?.displayName ??
        (review.reviewerName.isNotEmpty ? review.reviewerName : review.reviewerId);
    final revieweeName =
        reviewee?.displayName ?? review.revieweeId;

    return Container(
      color: isRemoved ? Colors.red.shade50 : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: stars + removed badge + date
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
                    color: isRemoved ? Colors.grey : Colors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isRemoved)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.red.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block,
                          size: 11, color: Colors.red.shade700),
                      const SizedBox(width: 3),
                      Text(
                        'Removed',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (review.createdAt != null)
                Text(
                  _fmtDate(review.createdAt!),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Comment text
          if (review.comment.isNotEmpty)
            Text(
              review.comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  height: 1.4,
                  color: isRemoved ? Colors.grey : null),
            )
          else
            Text('No comment.',
                style: TextStyle(
                    color: cs.outline, fontSize: 13)),
          const SizedBox(height: 6),

          // Reviewer → Reviewee
          Text(
            'By: $reviewerName  →  For: $revieweeName',
            style: const TextStyle(
                fontSize: 12, color: Colors.grey),
          ),

          // View profile link
          TextButton.icon(
            icon: const Icon(Icons.person_outline, size: 14),
            label: const Text('View reviewer profile'),
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

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isRemoved)
                TextButton.icon(
                  icon: const Icon(Icons.block,
                      size: 16, color: Colors.red),
                  label: const Text('Remove',
                      style: TextStyle(color: Colors.red)),
                  onPressed: () => _remove(context),
                ),
              if (isRemoved)
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
    final reviewer = AppState.instance.users
        .where((u) => u.uid == review.reviewerId)
        .firstOrNull;
    final reviewerName = reviewer?.displayName ?? review.reviewerName;

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Remove Review'),
        content: Text(
          'Remove this review by $reviewerName?\n\n'
          'The review will be hidden from the public and the reviewer '
          'will not be able to submit another review for this project.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    await AppState.instance.adminRemoveReview(review);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Review removed.')),
      );
    }
    onChanged();
  }

  Future<void> _restore(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Restore Review'),
        content: const Text(
            'Restore this review? It will become visible to the public again '
            'and the reviewer\'s rating will be reinstated.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    await AppState.instance.adminRestoreReview(review);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Review restored and published.')),
      );
    }
    onChanged();
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}
