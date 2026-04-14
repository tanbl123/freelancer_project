import 'dart:io';

import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/file_storage_service.dart';
import '../../../state/app_state.dart';
import '../models/marketplace_post.dart';
import 'post_form_page.dart';

class MarketplaceFeedPage extends StatefulWidget {
  const MarketplaceFeedPage({super.key});

  @override
  State<MarketplaceFeedPage> createState() => _MarketplaceFeedPageState();
}

class _MarketplaceFeedPageState extends State<MarketplaceFeedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkConnectivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.instance.isOnline();
    if (!online) {
      await AppState.instance.reloadPosts(useCache: true);
      if (mounted) setState(() => _isOffline = true);
    } else {
      // Cache latest 20 jobs in background
      SupabaseService.instance.cacheJobs(
        AppState.instance.posts
            .where((p) => p.type == PostType.jobRequest)
            .take(20)
            .toList(),
      );
      if (mounted) setState(() => _isOffline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final allPosts = AppState.instance.posts;
        final jobs =
            allPosts.where((p) => p.type == PostType.jobRequest).toList();
        final services =
            allPosts.where((p) => p.type == PostType.serviceOffering).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Marketplace'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Jobs (${jobs.length})'),
                Tab(text: 'Services (${services.length})'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PostFormPage()),
            ).then((_) => setState(() {})),
            icon: const Icon(Icons.add),
            label: const Text('Post'),
          ),
          body: Column(
            children: [
              if (_isOffline)
                MaterialBanner(
                  content:
                      const Text('You are offline. Showing cached jobs.'),
                  leading: const Icon(Icons.wifi_off, color: Colors.orange),
                  backgroundColor: Colors.orange.shade50,
                  actions: [
                    TextButton(
                      onPressed: _checkConnectivity,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PostList(posts: jobs, label: 'No job listings yet.'),
                    _PostList(
                        posts: services,
                        label: 'No service offerings yet.'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({required this.posts, required this.label});
  final List<MarketplacePost> posts;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => AppState.instance.reloadPosts(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: posts.length,
        itemBuilder: (context, index) => _PostCard(post: posts[index]),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final MarketplacePost post;

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isOwner = user?.uid == post.ownerId;
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (post.imageUrl != null &&
                FileStorageService.instance.fileExists(post.imageUrl))
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.file(
                  File(post.imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text(
                          post.type == PostType.jobRequest ? 'Job' : 'Service',
                          style: const TextStyle(fontSize: 11),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  if (post.skills.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: post.skills
                          .take(4)
                          .map((s) => Chip(
                                label: Text(s,
                                    style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                backgroundColor:
                                    colors.secondaryContainer,
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(post.ownerName,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ),
                      Icon(Icons.attach_money,
                          size: 14, color: Colors.grey.shade600),
                      Text(
                        'RM ${post.minimumBudget.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 2),
                      Text(
                        post.deadline
                            .toLocal()
                            .toString()
                            .split(' ')
                            .first,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  if (isOwner) ...[
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
                              builder: (_) =>
                                  PostFormPage(existing: post),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          onPressed: () => _confirmDelete(context),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PostDetailSheet(post: post),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content:
            const Text('Are you sure you want to delete this listing?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              AppState.instance.deletePost(post.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _PostDetailSheet extends StatelessWidget {
  const _PostDetailSheet({required this.post});
  final MarketplacePost post;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (post.imageUrl != null &&
              FileStorageService.instance.fileExists(post.imageUrl))
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(post.imageUrl!),
                  height: 200, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          Text(post.title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(post.description,
              style: const TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: 16),
          _DetailRow(
              icon: Icons.person_outline, label: 'Posted by', value: post.ownerName),
          _DetailRow(
              icon: Icons.attach_money,
              label: 'Budget',
              value: 'RM ${post.minimumBudget.toStringAsFixed(0)}'),
          _DetailRow(
              icon: Icons.calendar_today,
              label: 'Deadline',
              value: post.deadline.toLocal().toString().split(' ').first),
          if (post.skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Required Skills',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: post.skills
                  .map((s) => Chip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          if (AppState.instance.currentUser?.role == 'freelancer' &&
              post.type == PostType.jobRequest)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/applications/apply',
                    arguments: post);
              },
              icon: const Icon(Icons.send),
              label: const Text('Apply Now'),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
