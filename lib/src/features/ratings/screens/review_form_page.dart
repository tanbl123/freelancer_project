import 'package:flutter/material.dart';

import '../../../state/app_state.dart';
import '../models/review_item.dart';

class ReviewFormPage extends StatefulWidget {
  const ReviewFormPage({super.key});

  @override
  State<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<ReviewFormPage> {
  final _commentController = TextEditingController();
  int _selectedStars = 5;
  String? _targetFreelancerId;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a feedback comment.')),
      );
      return;
    }
    final user = AppState.instance.currentUser;
    final review = ReviewItem(
      id: AppState.instance.newId,
      projectId: 'project-1',
      reviewerId: user?.uid ?? 'anon',
      freelancerId: _targetFreelancerId ?? 'fr-1',
      stars: _selectedStars,
      comment: comment,
      createdAt: DateTime.now(),
    );
    AppState.instance.addReview(review);
    _commentController.clear();
    setState(() {
      _selectedStars = 5;
      _targetFreelancerId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final reviews = AppState.instance.reviews;
        final freelancers = AppState.instance.users
            .where((u) => u.role == 'freelancer')
            .toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Reviews & Ratings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Submit form card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Leave a Review',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (freelancers.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _targetFreelancerId,
                          decoration: const InputDecoration(
                            labelText: 'Freelancer',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Select freelancer'),
                          items: freelancers
                              .map((f) => DropdownMenuItem(
                                    value: f.uid,
                                    child: Text(f.displayName),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _targetFreelancerId = v;
                          }),
                        ),
                      const SizedBox(height: 12),
                      const Text('Rating:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Row(
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          return IconButton(
                            onPressed: () => setState(() => _selectedStars = star),
                            icon: Icon(
                              star <= _selectedStars ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                          );
                        }),
                      ),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Your feedback',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.send),
                          label: const Text('Submit Review'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Reviews list
              Row(
                children: [
                  const Text('Reviews',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${reviews.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (reviews.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No reviews yet.', style: TextStyle(color: Colors.grey)),
                )
              else
                ...reviews.map((review) => _ReviewCard(review: review)),
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
                    review.createdAt!.toLocal().toString().split(' ').first,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(review.comment),
            const SizedBox(height: 4),
            Text(
              'For: ${review.freelancerId}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
