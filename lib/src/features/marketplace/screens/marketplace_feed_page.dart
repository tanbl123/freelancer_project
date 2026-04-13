import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../config/firebase_bootstrap.dart';
import '../controllers/marketplace_controller.dart';
import '../models/marketplace_post.dart';

class MarketplaceFeedPage extends StatefulWidget {
  const MarketplaceFeedPage({super.key});

  @override
  State<MarketplaceFeedPage> createState() => _MarketplaceFeedPageState();
}

class _MarketplaceFeedPageState extends State<MarketplaceFeedPage> {
  final _controller = MarketplaceController();

  List<MarketplacePost> get _previewPosts => [
        MarketplacePost(
          id: 'preview-1',
          ownerId: 'client-1',
          ownerName: 'Alicia Tan',
          title: 'Build responsive Flutter landing page',
          description: 'Need Flutter web layout + Firebase login integration.',
          minimumBudget: 450,
          deadline: DateTime.now().add(const Duration(days: 5)),
          skills: const ['Flutter', 'Firebase'],
          type: PostType.jobRequest,
        ),
        MarketplacePost(
          id: 'preview-2',
          ownerId: 'freelancer-9',
          ownerName: 'Zi Zhang',
          title: 'UI/UX audit service',
          description: 'I provide UX audit reports with actionable fixes.',
          minimumBudget: 300,
          deadline: DateTime.now().add(const Duration(days: 10)),
          skills: const ['Figma', 'Research'],
          type: PostType.serviceOffering,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace Feed')),
      body: FirebaseBootstrap.isEnabled
          ? StreamBuilder<List<MarketplacePost>>(
              stream: _controller.streamActiveFeed(PostType.jobRequest),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final posts = snapshot.data ?? const [];
                if (posts.isEmpty) {
                  return const Center(child: Text('No active jobs right now.'));
                }
                return _PostList(posts: posts);
              },
            )
          : _PostList(posts: _previewPosts, bannerText: 'Preview mode: Firebase not configured yet.'),
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({required this.posts, this.bannerText});

  final List<MarketplacePost> posts;
  final String? bannerText;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length + (bannerText == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (bannerText != null && index == 0) {
          return Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(bannerText!),
            ),
          );
        }

        final itemIndex = bannerText == null ? index : index - 1;
        final post = posts[itemIndex];
        return Card(
          child: ListTile(
            title: Text(post.title),
            subtitle: Text(
              '${post.ownerName}\nBudget: RM ${post.minimumBudget.toStringAsFixed(0)} | Due: ${post.deadline.toLocal().toString().split(' ').first}',
            ),
            isThreeLine: true,
            trailing: Chip(label: Text(post.type == PostType.jobRequest ? 'Job' : 'Service')),
          ),
        );
      },
    );
  }
}
