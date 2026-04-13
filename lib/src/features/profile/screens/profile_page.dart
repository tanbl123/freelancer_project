import 'package:flutter/material.dart';

import '../../../state/app_state.dart';
import '../models/profile_user.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
        final reviews = AppState.instance.reviews
            .where((r) => r.freelancerId == user.uid)
            .toList();
        final avgRating = reviews.isEmpty
            ? null
            : reviews.map((r) => r.stars).reduce((a, b) => a + b) /
                reviews.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Profile',
                onPressed: () => _showEditDialog(context, user),
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
                          radius: 36,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            user.displayName[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
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
                              if (avgRating != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 14, color: Colors.amber),
                                    Text(
                                      ' ${avgRating.toStringAsFixed(1)} (${reviews.length} reviews)',
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
                const SizedBox(height: 16),

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
                    ),
                  ),
                ),

                // Skills
                if (user.role == 'freelancer') ...[
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

                // Stats
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
                        label: 'Applications Submitted',
                        value: AppState.instance.applications
                            .where((a) => a.freelancerId == user.uid)
                            .length
                            .toString(),
                      ),
                      _StatRow(
                        label: 'Reviews Received',
                        value: reviews.length.toString(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    onPressed: () => _showEditDialog(context, user),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, ProfileUser user) {
    showDialog(
      context: context,
      builder: (_) => _EditProfileDialog(user: user),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});
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
                Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user});
  final ProfileUser user;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _skillsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _skillsController =
        TextEditingController(text: widget.user.skills.join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }
    final updated = ProfileUser(
      uid: widget.user.uid,
      displayName: name,
      role: widget.user.role,
      bio: _bioController.text.trim(),
      skills: _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
    AppState.instance.updateProfile(updated);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: 'Display Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                  labelText: 'Bio', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            if (widget.user.role == 'freelancer') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: 'Skills (comma-separated)',
                  border: OutlineInputBorder(),
                  hintText: 'Flutter, Firebase, Dart',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
