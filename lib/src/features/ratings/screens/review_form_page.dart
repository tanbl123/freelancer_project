import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../state/app_state.dart';
import '../../transactions/models/project_item.dart';
import '../models/review_item.dart';
import 'freelancer_stats_page.dart';

class ReviewFormPage extends StatefulWidget {
  const ReviewFormPage({super.key});

  @override
  State<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<ReviewFormPage> {
  static const _uuid = Uuid();
  final _commentController = TextEditingController();
  int _selectedStars = 5;
  ProjectItem? _selectedProject;
  List<ProjectItem> _completedProjects = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCompletedProjects();
  }

  Future<void> _loadCompletedProjects() async {
    final user = AppState.instance.currentUser;
    if (user == null) return;
    final projects = AppState.instance.userProjects
        .where((p) => p.status == 'completed' && p.clientId == user.uid)
        .toList();
    if (mounted) {
      setState(() {
        _completedProjects = projects;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a completed project.')),
      );
      return;
    }
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a feedback comment.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final user = AppState.instance.currentUser!;
    final review = ReviewItem(
      id: _uuid.v4(),
      projectId: _selectedProject!.id,
      reviewerId: user.uid,
      freelancerId: _selectedProject!.freelancerId,
      stars: _selectedStars,
      comment: comment,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final error = await AppState.instance.addReview(review);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      final freelancerName =
          _selectedProject!.freelancerName ?? 'the freelancer';
      final submittedStars = _selectedStars;
      _commentController.clear();
      setState(() {
        _selectedProject = null;
        _selectedStars = 5;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Review submitted!'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () {
              Share.share(
                  'I gave $freelancerName $submittedStars/5 stars on the FreelancerApp!');
            },
          ),
        ),
      );
      await Share.share(
          'I just reviewed $freelancerName and gave them $submittedStars/5 stars on FreelancerApp! Great work!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isClient = user?.role == 'client';

    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final allReviews = AppState.instance.reviews;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reviews & Ratings'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Submit form — only for clients with completed projects
                    if (isClient) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Leave a Review',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              if (_completedProjects.isEmpty)
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No completed projects yet.\nReviews can only be submitted after a project is completed.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              else ...[
                                DropdownButtonFormField<ProjectItem>(
                                  initialValue: _selectedProject,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Completed Project',
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                        Icon(Icons.assignment_turned_in),
                                  ),
                                  hint: const Text('Choose a project'),
                                  items: _completedProjects
                                      .map((p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(
                                              '${p.jobTitle ?? 'Project'} — ${p.freelancerName ?? p.freelancerId}',
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedProject = v),
                                ),
                                const SizedBox(height: 12),
                                const Text('Rating:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500)),
                                Row(
                                  children: List.generate(5, (index) {
                                    final star = index + 1;
                                    return IconButton(
                                      onPressed: () => setState(
                                          () => _selectedStars = star),
                                      icon: Icon(
                                        star <= _selectedStars
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                        size: 32,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _commentController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Your feedback',
                                    border: OutlineInputBorder(),
                                    hintText:
                                        'Share your experience working with this freelancer...',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed:
                                        _isSubmitting ? null : _submit,
                                    icon: _isSubmitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2))
                                        : const Icon(Icons.send),
                                    label:
                                        const Text('Submit Review'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Reviews list header
                    Row(
                      children: [
                        const Text('Reviews',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${allReviews.length}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        if (user?.role == 'freelancer')
                          TextButton.icon(
                            icon: const Icon(Icons.bar_chart, size: 16),
                            label: const Text('My Stats'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FreelancerStatsPage(
                                    freelancerId: user!.uid),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (allReviews.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No reviews yet.',
                            style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...allReviews.map((r) => _ReviewCard(review: r)),
                  ],
                ),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final ReviewItem review;

  @override
  Widget build(BuildContext context) {
    final stars = review.stars;
    final freelancer = AppState.instance.users
        .where((u) => u.uid == review.freelancerId)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < stars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$stars/5',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (review.createdAt != null)
                  Text(
                    review.createdAt!
                        .toLocal()
                        .toString()
                        .split(' ')
                        .first,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(review.comment,
                style: const TextStyle(height: 1.4)),
            const SizedBox(height: 4),
            Text(
              'For: ${freelancer?.displayName ?? review.freelancerId}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
