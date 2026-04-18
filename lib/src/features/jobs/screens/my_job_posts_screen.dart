import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_router.dart';
import '../../../shared/enums/job_status.dart';
import '../../../state/app_state.dart';
import '../models/job_post.dart';
import '../widgets/job_badges.dart';

/// Standalone screen — wraps [MyJobPostsBody] with an AppBar and "Post a Job" FAB.
/// Accessible as a pushed route (e.g. from the profile page).
class MyJobPostsScreen extends StatelessWidget {
  const MyJobPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Job Posts')),
      body: const MyJobPostsBody(),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Post a Job'),
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.jobForm);
          AppState.instance.reloadMyJobPosts();
        },
      ),
    );
  }
}

/// Embeddable body — used inside [MyJobPostsScreen] and the "My Posts" tab
/// of [JobFeedScreen]. Owns its own Open / Closed / Cancelled sub-TabController.
class MyJobPostsBody extends StatefulWidget {
  const MyJobPostsBody({super.key});

  @override
  State<MyJobPostsBody> createState() => _MyJobPostsBodyState();
}

class _MyJobPostsBodyState extends State<MyJobPostsBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    AppState.instance.reloadMyJobPosts();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await AppState.instance.reloadMyJobPosts();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'Closed'),
            Tab(text: 'Cancelled'),
          ],
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) {
              final all = AppState.instance.myJobPosts;

              List<JobPost> byStatus(JobStatus s) =>
                  all.where((p) => p.status == s).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PostList(
                      posts: byStatus(JobStatus.open),
                      emptyMessage: 'No open job posts.',
                      emptyIcon: Icons.work_outline,
                    ),
                    _PostList(
                      posts: byStatus(JobStatus.closed),
                      emptyMessage: 'No closed posts.',
                      emptyIcon: Icons.lock_outline,
                    ),
                    _PostList(
                      posts: byStatus(JobStatus.cancelled),
                      emptyMessage: 'No cancelled posts.',
                      emptyIcon: Icons.cancel_outlined,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Post list per tab ──────────────────────────────────────────────────────

class _PostList extends StatelessWidget {
  const _PostList({
    required this.posts,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  final List<JobPost> posts;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon,
                size: 64,
                color:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(emptyMessage,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: posts.length,
      itemBuilder: (context, i) => _MyPostCard(post: posts[i]),
    );
  }
}

// ── Per-post card with inline actions ─────────────────────────────────────

class _MyPostCard extends StatefulWidget {
  const _MyPostCard({required this.post});
  final JobPost post;

  @override
  State<_MyPostCard> createState() => _MyPostCardState();
}

class _MyPostCardState extends State<_MyPostCard> {
  bool _loading = false;

  Future<void> _close() async {
    final confirmed = await _confirm('Close Post',
        'Close "${widget.post.title}"? It will be removed from the job feed.');
    if (!confirmed) return;
    setState(() => _loading = true);
    final err = await AppState.instance
        .closeJobPost(widget.post.id, widget.post.clientId);
    if (mounted) setState(() => _loading = false);
    _snack(err, 'Post closed.');
  }

  Future<void> _cancel() async {
    final confirmed = await _confirm(
        'Cancel Post', 'Cancel "${widget.post.title}"?');
    if (!confirmed) return;
    setState(() => _loading = true);
    final err = await AppState.instance
        .cancelJobPost(widget.post.id, widget.post.clientId);
    if (mounted) setState(() => _loading = false);
    _snack(err, 'Post cancelled.');
  }

  Future<void> _reopen() async {
    final confirmed = await _confirm('Reopen Post',
        'Reopen "${widget.post.title}"? It will appear in the job feed again.');
    if (!confirmed) return;
    setState(() => _loading = true);
    final err = await AppState.instance
        .reopenJobPost(widget.post.id, widget.post.clientId);
    if (mounted) setState(() => _loading = false);
    _snack(err, 'Post reopened.');
  }

  Future<void> _delete() async {
    final confirmed = await _confirm(
        'Delete Post', 'Permanently delete "${widget.post.title}"?');
    if (!confirmed) return;
    setState(() => _loading = true);
    final err = await AppState.instance
        .removeJobPost(widget.post.id, widget.post.clientId);
    if (mounted) setState(() => _loading = false);
    _snack(err, 'Post deleted.');
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String? error, String success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? success)));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final isOpen = p.status == JobStatus.open;
    final isClosed = p.status == JobStatus.closed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, AppRoutes.jobDetail,
            arguments: p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────────
                    Row(
                      children: [
                        JobStatusBadge(p.status),
                        const Spacer(),
                        Text(
                          p.createdAt != null
                              ? DateFormat('d MMM y').format(p.createdAt!)
                              : '',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Title ────────────────────────────────────────
                    Text(p.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),

                    // ── Stats row ────────────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${p.applicationCount} application${p.applicationCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        if (p.deadline != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.schedule,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Due ${DateFormat('d MMM').format(p.deadline!)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                        if (p.budgetDisplay != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            p.budgetDisplay!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 16),

                    // ── Actions ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isOpen) ...[
                          TextButton.icon(
                            icon: const Icon(Icons.edit_outlined,
                                size: 14),
                            label: const Text('Edit',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              await Navigator.pushNamed(
                                  context, AppRoutes.jobForm,
                                  arguments: p);
                              AppState.instance.reloadMyJobPosts();
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.lock_outline,
                                size: 14, color: Colors.orange),
                            label: const Text('Close',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.orange)),
                            onPressed: _close,
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined,
                                size: 14, color: Colors.red),
                            label: const Text('Cancel',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red)),
                            onPressed: _cancel,
                          ),
                        ],
                        if (isClosed)
                          TextButton.icon(
                            icon: const Icon(Icons.lock_open_outlined,
                                size: 14, color: Colors.green),
                            label: const Text('Reopen',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.green)),
                            onPressed: _reopen,
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: _delete,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
