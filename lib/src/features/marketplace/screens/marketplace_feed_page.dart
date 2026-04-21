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
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Clients default to Services tab (find freelancers to hire).
    // Freelancers default to Jobs tab (find work to apply for).
    final isClient = AppState.instance.currentUser?.role == UserRole.client;
    _tabController = TabController(length: 2, vsync: this, initialIndex: isClient ? 1 : 0);
    _checkConnectivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.instance.isOnline();
    if (!online) {
      await AppState.instance.reloadPosts(useCache: true);
      if (mounted) setState(() => _isOffline = true);
    } else {
      SupabaseService.instance.cacheJobs(
        AppState.instance.posts
            .where((p) => p.type == PostType.jobRequest)
            .take(20)
            .toList(),
      );
      if (mounted) setState(() => _isOffline = false);
    }
  }

  List<MarketplacePost> _filter(List<MarketplacePost> posts) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return posts;
    return posts.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.ownerName.toLowerCase().contains(q) ||
          p.skills.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.currentUser;
        final isClient = user?.role == UserRole.client;
        final allPosts = AppState.instance.posts;
        final jobs = _filter(
            allPosts.where((p) => p.type == PostType.jobRequest).toList());
        final services = _filter(
            allPosts.where((p) => p.type == PostType.serviceOffering).toList());

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Container(
              margin: EdgeInsets.all(8.0),
              padding: EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClient ? 'Find Talent' : 'Find Work',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (user != null)
                    Text(
                      'Hi, ${user.displayName.split(' ').first}!',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(104),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: isClient
                            ? 'Search services, skills, freelancers…'
                            : 'Search jobs, skills, clients…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  // Tabs
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.work_outline, size: 18),
                        text: 'Job Requests (${jobs.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.design_services_outlined,
                            size: 18),
                        text: 'Services (${services.length})',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostFormPage()),
            ).then((_) => setState(() {})),
            icon: const Icon(Icons.add),
            label: Text(isClient ? 'Post a Job' : 'Offer a Service'),
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
                    _PostList(
                      posts: jobs,
                      label: _searchQuery.isNotEmpty
                          ? 'No jobs match "$_searchQuery".'
                          : 'No job requests yet.',
                    ),
                    _PostList(
                      posts: services,
                      label: _searchQuery.isNotEmpty
                          ? 'No services match "$_searchQuery".'
                          : 'No service offerings yet.',
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────

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
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => AppState.instance.reloadPosts(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: posts.length,
        itemBuilder: (context, index) => _PostCard(post: posts[index]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final MarketplacePost post;

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isOwner = user?.uid == post.ownerId;
    final colors = Theme.of(context).colorScheme;
    final isJob = post.type == PostType.jobRequest;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => _showDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (post.imageUrl != null &&
                FileStorageService.instance.fileExists(post.imageUrl))
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.file(File(post.imageUrl!), fit: BoxFit.cover),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge + title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isJob
                              ? colors.primaryContainer
                              : colors.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isJob ? 'Job' : 'Service',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isJob
                                ? colors.onPrimaryContainer
                                : colors.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),

                  // Skills chips
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
                                backgroundColor: colors.secondaryContainer,
                              ))
                          .toList(),
                    ),
                  if (post.skills.isNotEmpty) const SizedBox(height: 10),

                  // Meta row: owner · budget · deadline
                  Row(
                    children: [
                      // Owner avatar
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: colors.primaryContainer,
                        child: Text(
                          post.ownerName.isNotEmpty
                              ? post.ownerName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontSize: 10, color: colors.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.ownerName,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Budget
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'RM ${post.minimumBudget.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Deadline
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            post.deadline
                                .toLocal()
                                .toString()
                                .split(' ')
                                .first,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Owner actions (edit / delete)
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
                                builder: (_) => PostFormPage(existing: post)),
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
        title: const Text('Delete Listing'),
        content: const Text('Are you sure you want to delete this listing?'),
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
                const SnackBar(content: Text('Listing deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PostDetailSheet extends StatelessWidget {
  const _PostDetailSheet({required this.post});
  final MarketplacePost post;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = AppState.instance.currentUser;
    final isJob = post.type == PostType.jobRequest;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          // Handle bar
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

          // Cover image
          if (post.imageUrl != null &&
              FileStorageService.instance.fileExists(post.imageUrl))
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(post.imageUrl!),
                  height: 200, fit: BoxFit.cover),
            ),
          const SizedBox(height: 14),

          // Title + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(post.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isJob
                      ? colors.primaryContainer
                      : colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isJob ? 'Job Request' : 'Service',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isJob
                        ? colors.onPrimaryContainer
                        : colors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(post.description,
              style: const TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: 16),

          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => Navigator.pushNamed(
              context,
              '/profile/view',
              arguments: post.ownerId,
            ),
            child: _DetailRow(
              icon: Icons.person_outline,
              label: 'Posted by',
              value: '${post.ownerName}  ›',
            ),
          ),
          _DetailRow(
              icon: Icons.attach_money,
              label: isJob ? 'Price' : 'Starting at',
              value: 'RM ${post.minimumBudget.toStringAsFixed(0)}'),
          _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Deadline',
              value: post.deadline.toLocal().toString().split(' ').first),

          if (post.skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Required Skills',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.skills
                  .map((s) => Chip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 24),

          // Apply button: freelancers on job requests only
          if (user?.role == UserRole.freelancer && isJob)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/applications/apply',
                    arguments: post);
              },
              icon: const Icon(Icons.send),
              label: const Text('Apply Now'),
            ),

          // Hire button: clients on service offerings only
          if (user?.role == UserRole.client && !isJob)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/applications/apply',
                    arguments: post);
              },
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Request This Service'),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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
