import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_router.dart';
import '../../../shared/enums/user_role.dart';
import '../../../state/app_state.dart';
import '../models/job_post.dart';
import '../widgets/job_badges.dart';
import 'my_job_posts_screen.dart';

/// Jobs tab — inner tabs depend on role:
///
/// - **Client**: Browse + My Posts tabs, with "Post a Job" FAB on My Posts.
/// - **Freelancer**: Browse only — freelancers apply to jobs, not post them.
class JobFeedScreen extends StatefulWidget {
  const JobFeedScreen({super.key});

  @override
  State<JobFeedScreen> createState() => _JobFeedScreenState();
}

class _JobFeedScreenState extends State<JobFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _isFreelancer = false;

  @override
  void initState() {
    super.initState();
    _isFreelancer =
        AppState.instance.currentUser?.role == UserRole.freelancer;
    _tabs = TabController(
        length: _isFreelancer ? 1 : 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onMyPosts = !_isFreelancer && _tabs.index == 1;

    return Scaffold(
      body: Column(
        children: [
          // Only show the tab bar when there are multiple tabs (client)
          if (!_isFreelancer)
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Browse'),
                Tab(text: 'My Posts'),
              ],
            ),
          Expanded(
            child: _isFreelancer
                ? const _JobBrowseTab()
                : TabBarView(
                    controller: _tabs,
                    children: const [
                      _JobBrowseTab(),
                      MyJobPostsBody(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: onMyPosts
          ? FloatingActionButton.extended(
              heroTag: 'job_feed_fab',
              icon: const Icon(Icons.add),
              label: const Text('Post a Job'),
              onPressed: () async {
                await Navigator.pushNamed(context, AppRoutes.jobForm);
                AppState.instance.reloadMyJobPosts();
              },
            )
          : null,
    );
  }
}

// ── Browse tab ─────────────────────────────────────────────────────────────

class _JobBrowseTab extends StatefulWidget {
  const _JobBrowseTab();

  @override
  State<_JobBrowseTab> createState() => _JobBrowseTabState();
}

class _JobBrowseTabState extends State<_JobBrowseTab> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Load jobs the first time this tab is shown.
    AppState.instance.reloadJobPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await AppState.instance.reloadJobPosts(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      category: _selectedCategory,
    );
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _applySearch() {
    AppState.instance.reloadJobPosts(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      category: _selectedCategory,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    AppState.instance.reloadJobPosts(category: _selectedCategory);
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _FilterSheet(
        selected: _selectedCategory,
        onSelect: (cat) {
          setState(() => _selectedCategory = cat);
          AppState.instance.reloadJobPosts(
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
            category: cat,
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final posts = AppState.instance.jobPosts;
        final isFromCache = AppState.instance.jobPostsFromCache;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              // ── Search bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search jobs, skills, clients…',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _applySearch(),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: _selectedCategory != null,
                        child: IconButton.outlined(
                          icon: const Icon(Icons.tune),
                          tooltip: 'Filter',
                          onPressed: _showFilterSheet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category chip bar ───────────────────────────────────
              SliverToBoxAdapter(
                child: _CategoryChipBar(
                  selected: _selectedCategory,
                  onSelect: (cat) {
                    setState(() => _selectedCategory = cat);
                    AppState.instance.reloadJobPosts(
                      search: _searchController.text.trim().isEmpty
                          ? null
                          : _searchController.text.trim(),
                      category: cat,
                    );
                  },
                ),
              ),

              // ── Offline banner ──────────────────────────────────────
              if (isFromCache)
                const SliverToBoxAdapter(child: _OfflineBanner()),

              // ── Empty state ─────────────────────────────────────────
              if (posts.isEmpty && !_isRefreshing)
                SliverFillRemaining(
                  child: _EmptyState(
                      isFiltered: _searchController.text.isNotEmpty ||
                          _selectedCategory != null),
                )
              else
                // ── Job list ──────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _JobCard(
                        post: posts[i],
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.jobDetail,
                          arguments: posts[i],
                        ),
                      ),
                      childCount: posts.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Category chip bar ──────────────────────────────────────────────────────

class _CategoryChipBar extends StatelessWidget {
  const _CategoryChipBar({required this.selected, required this.onSelect});
  final String? selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final cats = AppState.instance.categories;
    if (cats.isEmpty) return const SizedBox(height: 44);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...cats.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(cat.displayName),
                  selected: selected == cat.id,
                  onSelected: (_) =>
                      onSelect(selected == cat.id ? null : cat.id),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Offline banner ─────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final syncedAt = AppState.instance.jobCacheLastSyncedAt;
    final ageLabel = _cacheAgeLabel(syncedAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You\'re offline — showing cached jobs',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                if (ageLabel != null)
                  Text(ageLabel,
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade700)),
              ],
            ),
          ),
          Icon(Icons.swipe_down_outlined,
              size: 16, color: Colors.orange.shade400),
        ],
      ),
    );
  }

  static String? _cacheAgeLabel(DateTime? syncedAt) {
    if (syncedAt == null) return null;
    final diff = DateTime.now().difference(syncedAt);
    if (diff.inSeconds < 60) return 'Just cached';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'Cached ${m == 1 ? '1 minute' : '$m minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Cached ${h == 1 ? '1 hour' : '$h hours'} ago';
    }
    final d = diff.inDays;
    return 'Cached ${d == 1 ? 'yesterday' : '$d days ago'}';
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltered});
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 72,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? 'No jobs match your search.'
                  : 'No open jobs available right now.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (isFiltered)
              const Text('Try adjusting your filters or search terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ── Filter bottom sheet ────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.selected, required this.onSelect});
  final String? selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final cats = AppState.instance.categories;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filter by Category',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (selected != null)
                  TextButton(
                    onPressed: () => onSelect(null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats
                  .map((cat) => ChoiceChip(
                        label: Text(cat.displayName),
                        selected: selected == cat.id,
                        onSelected: (_) => onSelect(cat.id),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Job card ───────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.post,
    required this.onTap,
    this.showStatusBadge = false,
  });

  final JobPost post;
  final VoidCallback onTap;
  final bool showStatusBadge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final daysLeft = post.daysUntilDeadline;
    final deadlineColor =
        daysLeft != null && daysLeft <= 3 ? Colors.red : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────
              Row(
                children: [
                  JobCategoryBadge(post.category),
                  if (showStatusBadge) ...[
                    const SizedBox(width: 6),
                    JobStatusBadge(post.status),
                  ],
                  const Spacer(),
                  if (post.applicationCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('${post.applicationCount}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Title ──────────────────────────────────────────────
              Text(post.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),

              // ── Client name ────────────────────────────────────────
              Text('By ${post.clientName}',
                  style: TextStyle(
                      fontSize: 12, color: colors.onSurfaceVariant)),
              const SizedBox(height: 8),

              // ── Skills ─────────────────────────────────────────────
              if (post.requiredSkills.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...post.requiredSkills.take(4).map((s) => Chip(
                          label: Text(s,
                              style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )),
                    if (post.requiredSkills.length > 4)
                      Chip(
                        label: Text('+${post.requiredSkills.length - 4}',
                            style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // ── Footer: budget + deadline ──────────────────────────
              Row(
                children: [
                  if (post.budgetDisplay != null) ...[
                    const Icon(Icons.attach_money,
                        size: 14, color: Colors.green),
                    Text(post.budgetDisplay!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green)),
                    const SizedBox(width: 12),
                  ],
                  if (daysLeft != null) ...[
                    Icon(Icons.schedule, size: 13, color: deadlineColor),
                    const SizedBox(width: 3),
                    Text(
                      daysLeft < 0
                          ? 'Deadline passed'
                          : daysLeft == 0
                              ? 'Closing today'
                              : daysLeft == 1
                                  ? '1 day left'
                                  : '$daysLeft days left',
                      style:
                          TextStyle(fontSize: 11, color: deadlineColor),
                    ),
                  ] else if (post.deadline != null) ...[
                    Icon(Icons.schedule, size: 13, color: deadlineColor),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('d MMM y').format(post.deadline!),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
