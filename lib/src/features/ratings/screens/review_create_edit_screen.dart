import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../state/app_state.dart';
import '../../transactions/models/project_item.dart';
import '../models/review_item.dart';

/// Unified create / edit screen for a [ReviewItem].
///
/// **Create mode** — pass [project]. The reviewee is inferred:
///   - Current user is client  → reviewee = project.freelancerId
///   - Current user is freelancer → reviewee = project.clientId
///
/// **Edit mode** — pass [review]. Stars and comment are pre-filled.
///
/// Returns `true` via [Navigator.pop] when the action succeeds.
class ReviewCreateEditScreen extends StatefulWidget {
  const ReviewCreateEditScreen({
    super.key,
    this.project,
    this.review,
  }) : assert(project != null || review != null,
            'Provide either project (create) or review (edit)');

  final ProjectItem? project;
  final ReviewItem? review;

  bool get isEdit => review != null;

  @override
  State<ReviewCreateEditScreen> createState() => _ReviewCreateEditScreenState();
}

class _ReviewCreateEditScreenState extends State<ReviewCreateEditScreen> {
  static const _uuid = Uuid();
  final _commentCtrl = TextEditingController();
  int _stars = 5;
  bool _submitting = false;

  // ── Unsaved-changes detection ─────────────────────────────────────────────
  late int _origStars;
  late String _origComment;

  bool get _hasChanges =>
      _stars != _origStars ||
      _commentCtrl.text.trim() != _origComment;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _stars = widget.review!.stars;
      _commentCtrl.text = widget.review!.comment;
    }
    _origStars   = _stars;
    _origComment = _commentCtrl.text.trim();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final user = AppState.instance.currentUser!;
    String? err;
    // Capture reviewee name before any async gaps so it's available after pop.
    String shareRevieweeName = '';

    if (widget.isEdit) {
      // Edit mode
      err = await AppState.instance.editReview(
        widget.review!,
        _stars,
        _commentCtrl.text.trim(),
      );
    } else {
      // Create mode — derive reviewee from project
      final project = widget.project!;
      final revieweeId = project.clientId == user.uid
          ? project.freelancerId
          : project.clientId;
      shareRevieweeName = project.clientId == user.uid
          ? (project.freelancerName ?? revieweeId)
          : (project.clientName ?? revieweeId);

      final review = ReviewItem(
        id: _uuid.v4(),
        projectId: project.id,
        reviewerId: user.uid,
        reviewerName: user.displayName,
        revieweeId: revieweeId,
        stars: _stars,
        comment: _commentCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      err = await AppState.instance.addReview(review);
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    } else {
      // Capture the ScaffoldMessenger BEFORE popping so the reference stays
      // valid after this widget is removed from the tree.  Using the context
      // after Navigator.pop starts the dispose cycle, which causes the
      // auto-dismiss timer to never fire.
      final messenger = ScaffoldMessenger.of(context);
      final capturedStars = _stars;
      final capturedName  = shareRevieweeName;
      final showShare     = !widget.isEdit && capturedName.isNotEmpty;

      Navigator.pop(context, true);

      if (showShare) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 4),
              content: Text('Review submitted! $capturedStars ⭐'),
              action: SnackBarAction(
                label: 'Share',
                onPressed: () => Share.share(
                  'I just gave $capturedName $capturedStars/5 stars on FreelanceHub! '
                  'Great work 🎉',
                ),
              ),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final project = widget.project;
    final review  = widget.review;
    final user    = AppState.instance.currentUser!;

    // Determine who is being reviewed for display purposes
    String revieweeName;
    if (project != null) {
      revieweeName = project.clientId == user.uid
          ? (project.freelancerName ?? 'Freelancer')
          : (project.clientName ?? 'Client');
    } else {
      // Edit mode — look up from local users
      final reviewee = AppState.instance.users
          .where((u) => u.uid == review!.revieweeId)
          .firstOrNull;
      revieweeName = reviewee?.displayName ?? review!.revieweeId;
    }

    final projectTitle = project?.jobTitle
        ?? AppState.instance.projects
            .where((p) => p.id == review?.projectId)
            .firstOrNull
            ?.jobTitle
        ?? 'Project';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_hasChanges) { Navigator.pop(context); return; }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
                'You have unsaved changes. If you leave now, they will be lost.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Editing')),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Discard')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Review' : 'Write Review'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reviewee info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      revieweeName.isNotEmpty
                          ? revieweeName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reviewing',
                            style: TextStyle(
                                fontSize: 11, color: cs.outline)),
                        Text(revieweeName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        Text(projectTitle,
                            style: TextStyle(
                                fontSize: 12, color: cs.outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Star selector
            const Text('Your rating',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _stars = star),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      star <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: star <= _stars
                          ? Colors.amber
                          : cs.outlineVariant,
                    ),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _starLabel(_stars),
                style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),

            // Comment field
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Comment (optional)',
                hintText:
                    'Share your experience working with this person…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Icon(widget.isEdit ? Icons.save : Icons.send),
                label: Text(
                    widget.isEdit ? 'Save Changes' : 'Submit Review'),
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }

  String _starLabel(int s) {
    switch (s) {
      case 1:  return '⭐ Terrible';
      case 2:  return '⭐⭐ Bad';
      case 3:  return '⭐⭐⭐ Average';
      case 4:  return '⭐⭐⭐⭐ Good';
      case 5:  return '⭐⭐⭐⭐⭐ Excellent!';
      default: return '';
    }
  }
}
