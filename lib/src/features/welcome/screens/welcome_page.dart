import 'package:flutter/material.dart';

import '../../../routing/app_router.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // ── App icon + name ──────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.work_outline_rounded,
                            size: 48, color: colors.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'FreelanceHub',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connect. Collaborate. Get Paid.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Feature highlights ───────────────────────────────────────
                _FeatureCard(
                  icon: Icons.storefront_outlined,
                  color: Colors.blue,
                  title: 'Marketplace',
                  description:
                      'Browse job posts and service listings. Post your own opportunities and find the right talent.',
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.send_outlined,
                  color: Colors.green,
                  title: 'Apply with Confidence',
                  description:
                      'Submit proposals with a resume, budget and voice pitch. Clients review and accept the best fit.',
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.task_alt_outlined,
                  color: Colors.orange,
                  title: 'Milestone Payments',
                  description:
                      'Break work into milestones. Sign off each one digitally and release payment securely.',
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.star_outline_rounded,
                  color: Colors.purple,
                  title: 'Ratings & Reviews',
                  description:
                      'Build your reputation. See freelancer stats, earning charts and star ratings.',
                ),

                SizedBox(height: size.height * 0.04),

                // ── Action buttons ───────────────────────────────────────────
                FilledButton.icon(
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign In'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.login),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Create Account'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.register),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600], height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
