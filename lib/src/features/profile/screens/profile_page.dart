import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';
import '../../../features/ratings/screens/freelancer_stats_page.dart';
import 'edit_profile_page.dart';

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
    if (confirmed == true && context.mounted) {
      await AppState.instance.logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.welcome,
          (_) => false,
        );
      }
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
      if (context.mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.welcome,
            (_) => false,
          );
        }
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
        final isFreelancer = user.role == 'freelancer';
        final reviews = AppState.instance.reviews
            .where((r) => r.freelancerId == user.uid)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Profile'),
            actions: [
              if (isFreelancer)
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share Profile',
                  onPressed: () {
                    Share.share(
                        'Check out ${user.displayName} on FreelancerApp!\n'
                        'Rating: ${user.averageRating?.toStringAsFixed(1) ?? 'New'}/5'
                        ' (${user.totalReviews ?? 0} reviews)\n'
                        'Skills: ${user.skills.take(5).join(', ')}');
                  },
                ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Profile',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EditProfilePage()),
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
                                    user.role == 'client'
                                        ? Icons.business
                                        : Icons.code,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.role[0].toUpperCase() +
                                        user.role.substring(1),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 14),
                                  ),
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

                // Activity stats
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Activity',
                  icon: Icons.bar_chart,
                  child: Column(
                    children: [
                      _StatRow(
                        label: 'Listings Posted',
                        value: AppState.instance.posts
                            .where((p) => p.ownerId == user.uid)
                            .length
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
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action buttons
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
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfilePage()),
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
