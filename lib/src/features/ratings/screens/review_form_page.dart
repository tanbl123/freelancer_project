import 'package:flutter/material.dart';

import '../../../config/firebase_bootstrap.dart';
import '../models/review_item.dart';

class ReviewFormPage extends StatefulWidget {
  const ReviewFormPage({super.key});

  @override
  State<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<ReviewFormPage> {
  final _commentController = TextEditingController();
  int _selectedStars = 5;

  List<ReviewItem> get _previewReviews => const [
        ReviewItem(
          id: 'r-1',
          projectId: 'project-preview-1',
          reviewerId: 'client-1',
          freelancerId: 'fr-1',
          stars: 5,
          comment: 'Very responsive and delivered on schedule.',
        ),
      ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewMode = !FirebaseBootstrap.isEnabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews & Ratings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (previewMode)
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Preview mode: submit action disabled until Firebase is configured.'),
              ),
            ),
          const Text('Rate Freelancer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                onPressed: () => setState(() => _selectedStars = star),
                icon: Icon(star <= _selectedStars ? Icons.star : Icons.star_border),
              );
            }),
          ),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Feedback comment',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: previewMode
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wire this to RatingsController.createReview().')),
                    );
                  },
            child: const Text('Submit Review'),
          ),
          const SizedBox(height: 24),
          const Text('Latest Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._previewReviews.map(
            (review) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${'★' * review.stars} (${review.stars}/5)'),
              subtitle: Text(review.comment),
            ),
          ),
        ],
      ),
    );
  }
}
