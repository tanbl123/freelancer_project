import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../../routing/app_router.dart';
import '../../../shared/enums/account_status.dart';
import '../../../shared/enums/user_role.dart';
import '../../../shared/guards/access_guard.dart';
import '../../../state/app_state.dart';
import '../../../features/ratings/screens/freelancer_stats_page.dart';
import '../models/portfolio_item.dart';
import 'edit_profile_page.dart';
import 'portfolio_form_screen.dart';
import 'portfolio_list_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    // Just call logout — MainShell detects isLoggedIn becoming false
    // and navigates to the welcome screen automatically.
    if (confirmed == true && context.mounted) {
      await AppState.instance.logout();
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently delete your account and all your data. '
            'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final error = await AppState.instance.deleteAccount();
      // On success, MainShell detects isLoggedIn = false and redirects.
      // On error, show a snackbar so the user knows what went wrong.
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Not logged in.')),
          );
        }
        final isFreelancer = user.role == UserRole.freelancer;
        final isAdmin = user.role == UserRole.admin;
        final reviews = AppState.instance.reviews
            .where((r) => r.revieweeId == user.uid && r.isVisible)
            .toList();

        // ── Admin gets a completely different profile layout ──────────────
        if (isAdmin) {
          return Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildAdminBody(context, user),
            ),
          );
        }

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + name card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Profile photo
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: user.photoUrl != null &&
                                  File(user.photoUrl!).existsSync()
                              ? FileImage(File(user.photoUrl!))
                              : null,
                          child: user.photoUrl == null ||
                                  !File(user.photoUrl!).existsSync()
                              ? Text(
                                  user.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    user.role == UserRole.client
                                        ? Icons.business
                                        : user.role == UserRole.admin
                                            ? Icons.admin_panel_settings
                                            : Icons.code,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.role.displayName,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  _AccountStatusBadge(
                                      status: user.accountStatus),
                                ],
                              ),
                              if (user.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(user.email,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                              if (user.phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(user.phone,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                              if (isFreelancer &&
                                  (user.averageRating ?? 0) > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 16, color: Colors.amber),
                                    Text(
                                      ' ${user.averageRating!.toStringAsFixed(1)} (${user.totalReviews ?? 0} reviews)',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey),
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
                ),
                const SizedBox(height: 12),

                // Bio
                _SectionCard(
                  title: 'Bio',
                  icon: Icons.info_outline,
                  child: Text(
                    user.bio?.isNotEmpty == true
                        ? user.bio!
                        : 'No bio added yet. Tap edit to add one.',
                    style: TextStyle(
                      color: user.bio?.isNotEmpty == true
                          ? Colors.black87
                          : Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ),

                // Experience (freelancer only)
                if (isFreelancer && user.experience != null) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Experience',
                    icon: Icons.work_history_outlined,
                    child: Text(user.experience!,
                        style: const TextStyle(height: 1.4)),
                  ),
                ],

                // Skills
                if (isFreelancer) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Skills',
                    icon: Icons.build_outlined,
                    child: user.skills.isEmpty
                        ? const Text('No skills listed yet.',
                            style: TextStyle(color: Colors.grey))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: user.skills
                                .map((s) => Chip(
                                      label: Text(s),
                                      visualDensity:
                                          VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                  ),
                ],

                // My Portfolio (freelancer only)
                if (isFreelancer) ...[
                  const SizedBox(height: 12),
                  _MyPortfolioSection(userId: user.uid),
                ],

                // Activity stats — different rows per role
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Activity',
                  icon: Icons.bar_chart,
                  child: Column(
                    children: isFreelancer
                        ? [
                            // ── Freelancer stats ───────────────────────────
                            _StatRow(
                              label: 'Services Posted',
                              value: AppState.instance.myServices.length
                                  .toString(),
                            ),
                            _StatRow(
                              label: 'Applications',
                              value: AppState.instance.applications
                                  .where((a) => a.freelancerId == user.uid)
                                  .length
                                  .toString(),
                            ),
                            _StatRow(
                              label: 'Projects',
                              value: AppState.instance.userProjects.length
                                  .toString(),
                            ),
                            _StatRow(
                              label: 'Reviews Received',
                              value: reviews.length.toString(),
                            ),
                          ]
                        : [
                            // ── Client stats ───────────────────────────────
                            _StatRow(
                              label: 'Job Listings Posted',
                              value: AppState.instance.myJobPosts.length
                                  .toString(),
                            ),
                            _StatRow(
                              label: 'Projects',
                              value: AppState.instance.userProjects.length
                                  .toString(),
                            ),
                            _StatRow(
                              label: 'Reviews Received',
                              value: reviews.length.toString(),
                            ),
                          ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Role / Status action buttons ──────────────────────────
                // Active client: offer upgrade to freelancer
                if (AccessGuard.canRequestFreelancerUpgrade(user)) ...[
                  _FreelancerRequestBanner(
                    request: AppState.instance.myFreelancerRequest,
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.freelancerRequest),
                  ),
                  const SizedBox(height: 8),
                ],

                // Restricted / deactivated: appeal button
                if (AccessGuard.canSubmitAppeal(user)) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.gavel, color: Colors.orange),
                      label: const Text('Submit an Appeal',
                          style: TextStyle(color: Colors.orange)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange)),
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.appeal),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Freelancer: stats
                if (isFreelancer) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('View Earnings & Stats'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FreelancerStatsPage(freelancerId: user.uid),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Profile Details'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileDetailsPage()),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Change Password'),
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.changePassword),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('Delete Account',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _confirmDeleteAccount(context),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Logout',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _confirmLogout(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Admin profile body ─────────────────────────────────────────────────────

  Widget _buildAdminBody(BuildContext context, dynamic user) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Admin header card ──────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: cs.primaryContainer,
                  child: user.photoUrl != null &&
                          File(user.photoUrl!).existsSync()
                      ? null
                      : Text(
                          user.displayName[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                  backgroundImage: user.photoUrl != null &&
                          File(user.photoUrl!).existsSync()
                      ? FileImage(File(user.photoUrl!))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.admin_panel_settings,
                                size: 13, color: cs.primary),
                            const SizedBox(width: 4),
                            Text('System Administrator',
                                style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(user.email,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Profile ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Profile',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.person_outline),
            label: const Text('Profile Details'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileDetailsPage()),
            ),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 20),

        // ── Account actions ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Account',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.lock_outline),
            label: const Text('Change Password'),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.changePassword),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Logout',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _confirmLogout(context),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

// ── Account status inline badge ──────────────────────────────────────────────

class _AccountStatusBadge extends StatelessWidget {
  const _AccountStatusBadge({required this.status});
  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    // Only show badge when the status is noteworthy (not plain "active")
    if (status == AccountStatus.active) return const SizedBox.shrink();

    final (color, label) = switch (status) {
      AccountStatus.pendingVerification => (Colors.blue, 'Pending Verification'),
      AccountStatus.restricted => (Colors.orange, 'Restricted'),
      AccountStatus.deactivated => (Colors.red, 'Deactivated'),
      AccountStatus.active => (Colors.green, 'Active'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── My Portfolio section (freelancer's own profile) ──────────────────────────

/// Compact portfolio preview card shown on the freelancer's own profile.
/// Shows a 3-column thumbnail grid (max 6 previews) + "View All" button.
/// Tapping navigates to the full [PortfolioListPage].
class _MyPortfolioSection extends StatefulWidget {
  const _MyPortfolioSection({required this.userId});
  final String userId;

  @override
  State<_MyPortfolioSection> createState() => _MyPortfolioSectionState();
}

class _MyPortfolioSectionState extends State<_MyPortfolioSection> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await AppState.instance.loadPortfolioItems(widget.userId);
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  void _openPortfolioPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PortfolioListPage(
          freelancerId: widget.userId,
          isOwner: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final items = AppState.instance.portfolioItems;
        final count = items.length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.collections_bookmark_outlined,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        count > 0
                            ? 'My Portfolio ($count)'
                            : 'My Portfolio',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    // Add button
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () => Navigator.pushNamed(
                          context, AppRoutes.portfolioForm),
                    ),
                  ],
                ),

                // ── Body ────────────────────────────────────────────────────
                if (!_loaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No portfolio items yet. Tap Add to showcase your past work.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                else ...[
                  const SizedBox(height: 10),
                  // 3-column thumbnail grid (max 6 preview tiles)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1,
                    ),
                    itemCount: items.take(6).length,
                    itemBuilder: (ctx, i) =>
                        _PortfolioThumb(item: items[i]),
                  ),
                  const SizedBox(height: 10),
                  // "View All" button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.grid_view, size: 16),
                      label: Text(count > 6
                          ? 'View All $count Projects'
                          : 'View All Projects'),
                      onPressed: () => _openPortfolioPage(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Square thumbnail used in the compact grid ─────────────────────────────────

class _PortfolioThumb extends StatelessWidget {
  const _PortfolioThumb({required this.item});
  final PortfolioItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = item.imageUrl;

    Widget content;
    if (url != null && url.startsWith('http')) {
      content = Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(cs));
    } else if (url != null && File(url).existsSync()) {
      content = Image.file(File(url), fit: BoxFit.cover);
    } else {
      content = _fallback(cs);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          // Title overlay at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              color: Colors.black54,
              child: Text(
                item.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.image_outlined,
            color: cs.onSurface.withValues(alpha: 0.3)),
      );
}

// ── Profile Details page (pushed from the Profile Details button) ─────────────

class ProfileDetailsPage extends StatelessWidget {
  const ProfileDetailsPage({super.key});

  static Future<void> _openResume(BuildContext context, String path) async {
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Open File'),
          content: const Text(
            'No PDF viewer found on this device.\n\n'
            'Please install one of these free apps:\n'
            '• Google Drive\n'
            '• Adobe Acrobat Reader\n'
            '• WPS Office',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.currentUser;
        if (user == null) return const Scaffold(body: SizedBox.shrink());
        final isFreelancer = user.role == UserRole.freelancer;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile Details'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Profile',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + name card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: user.photoUrl != null &&
                                  File(user.photoUrl!).existsSync()
                              ? FileImage(File(user.photoUrl!))
                              : null,
                          child: user.photoUrl == null ||
                                  !File(user.photoUrl!).existsSync()
                              ? Text(
                                  user.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    user.role == UserRole.client
                                        ? Icons.business
                                        : Icons.code,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.role.displayName,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  _AccountStatusBadge(
                                      status: user.accountStatus),
                                ],
                              ),
                              if (user.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(user.email,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                              if (user.phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(user.phone,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                              if (isFreelancer &&
                                  (user.averageRating ?? 0) > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 16, color: Colors.amber),
                                    Text(
                                      ' ${user.averageRating!.toStringAsFixed(1)} (${user.totalReviews ?? 0} reviews)',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.grey),
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
                ),
                const SizedBox(height: 12),

                // Bio
                _SectionCard(
                  title: 'Bio',
                  icon: Icons.info_outline,
                  child: Text(
                    user.bio?.isNotEmpty == true
                        ? user.bio!
                        : 'No bio added yet. Tap edit to add one.',
                    style: TextStyle(
                      color: user.bio?.isNotEmpty == true
                          ? Colors.black87
                          : Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ),

                // Experience (freelancer only)
                if (isFreelancer) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Experience',
                    icon: Icons.work_history_outlined,
                    child: Text(
                      user.experience?.isNotEmpty == true
                          ? user.experience!
                          : 'No experience added yet. Tap edit to add.',
                      style: TextStyle(
                        color: user.experience?.isNotEmpty == true
                            ? Colors.black87
                            : Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                // Skills (freelancer only)
                if (isFreelancer) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Skills',
                    icon: Icons.build_outlined,
                    child: user.skills.isEmpty
                        ? const Text('No skills listed yet.',
                            style: TextStyle(color: Colors.grey))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: user.skills
                                .map((s) => Chip(
                                      label: Text(s),
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                  ),
                ],

                // Resume (freelancer only)
                if (isFreelancer) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Resume / CV',
                    icon: Icons.description_outlined,
                    child: user.resumeUrl != null &&
                            File(user.resumeUrl!).existsSync()
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.picture_as_pdf,
                                      color: Colors.red, size: 28),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      user.resumeUrl!
                                          .split('/')
                                          .last
                                          .split('\\')
                                          .last,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 16),
                                label: const Text('Preview Resume'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                ),
                                onPressed: () =>
                                    _openResume(context, user.resumeUrl!),
                              ),
                            ],
                          )
                        : const Text('No resume uploaded yet.',
                            style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Freelancer request status banner ─────────────────────────────────────────

class _FreelancerRequestBanner extends StatelessWidget {
  const _FreelancerRequestBanner({required this.request, required this.onTap});
  final dynamic request; // FreelancerRequest?
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (request == null) {
      // No request yet — show upgrade prompt
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.upgrade, color: Colors.blue),
          label: const Text('Become a Freelancer',
              style: TextStyle(color: Colors.blue)),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.blue)),
          onPressed: onTap,
        ),
      );
    }

    // Request exists — show status chip
    final statusName = (request.status.displayName as String?) ?? 'Pending';
    final color = switch (statusName) {
      'Approved' => Colors.green,
      'Rejected' => Colors.red,
      _ => Colors.orange,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.work_outline, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Freelancer Request: $statusName',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
