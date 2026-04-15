import 'dart:io';

import 'package:flutter/material.dart';

import '../../../common_widgets/module_menu_card.dart';
import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';

class ModuleDashboardPage extends StatelessWidget {
  const ModuleDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.currentUser;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
            automaticallyImplyLeading: false,
            actions: [
              // User avatar — tap to go to Profile
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.profile),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: user?.photoUrl != null &&
                            File(user!.photoUrl!).existsSync()
                        ? FileImage(File(user.photoUrl!))
                        : null,
                    child: user?.photoUrl == null ||
                            !File(user!.photoUrl!).existsSync()
                        ? Text(
                            user?.displayName[0].toUpperCase() ?? '?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info card
                if (user != null)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            child: Text(user.displayName[0].toUpperCase()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  user.role[0].toUpperCase() + user.role.substring(1),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Modules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ModuleMenuCard(
                  title: 'Marketplace',
                  subtitle: 'Browse jobs/services and post new listings',
                  icon: Icons.storefront,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.marketplace),
                ),
                ModuleMenuCard(
                  title: 'Applications',
                  subtitle: 'Freelancer proposals and applicant management',
                  icon: Icons.description,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.applications),
                ),
                ModuleMenuCard(
                  title: 'Transactions',
                  subtitle: 'Project milestones and progress tracking',
                  icon: Icons.assignment_turned_in,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.projects),
                ),
                ModuleMenuCard(
                  title: 'Reviews & Ratings',
                  subtitle: 'Submit and view freelancer reviews',
                  icon: Icons.star,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.ratings),
                ),
                ModuleMenuCard(
                  title: 'User Profile',
                  subtitle: 'View and edit your account information',
                  icon: Icons.person,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
