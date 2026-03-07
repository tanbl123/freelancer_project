import 'package:flutter/material.dart';

import '../../../common_widgets/common_widgets.dart';
import 'rating_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                const CircleAvatar(radius: 38, child: Icon(Icons.person, size: 38)),
                const SizedBox(height: 12),
                const Text('Zi Zhang', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Flutter Freelancer • Penang, Malaysia', style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: const [
                    Chip(label: Text('Flutter')),
                    Chip(label: Text('UI Design')),
                    Chip(label: Text('Firebase')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(child: StatCard(title: 'Rating', value: '4.9', icon: Icons.star_outline)),
                    SizedBox(width: 12),
                    Expanded(child: StatCard(title: 'Reviews', value: '104', icon: Icons.reviews_outlined)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...const [
                  SettingsRow(icon: Icons.edit_outlined, label: 'Edit Profile'),
                  SettingsRow(icon: Icons.badge_outlined, label: 'Skills & Resume'),
                  SettingsRow(icon: Icons.lock_outline, label: 'Change Password'),
                  SettingsRow(icon: Icons.photo_camera_outlined, label: 'Update Photo'),
                  SettingsRow(icon: Icons.delete_outline, label: 'Deactivate Account'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RatingScreen()),
                );
              },
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Open Rating Screen Demo'),
            ),
          ),
        ],
      ),
    );
  }
}
