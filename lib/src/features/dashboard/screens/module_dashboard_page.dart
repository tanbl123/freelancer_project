import 'package:flutter/material.dart';
import 'package:freelancer_project/src/common_widgets/module_menu_card.dart';

import '../../../routing/app_router.dart';

class ModuleDashboardPage extends StatelessWidget{
  const ModuleDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Module Dashboard'),
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tap a module to preview the UI flow.',
              style: TextStyle(
                  fontSize: 16
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            ModuleMenuCard(
                title: 'Marketplace Module',
                subtitle: 'Browse jobs/services and create post screens',
                icon: Icons.storefront,
                onTap: ()=>Navigator.pushNamed(
                    context, AppRoutes.marketplace
                ),
            ),
            ModuleMenuCard(
              title: 'Applications Module',
              subtitle: 'Freelancer proposals and client applicant list',
              icon: Icons.description,
              onTap: ()=>Navigator.pushNamed(
                  context, AppRoutes.applications
              ),
            ),
            ModuleMenuCard(
              title: 'Transactions Module',
              subtitle: 'Project milestones and progress tracking',
              icon: Icons.assignment_turned_in,
              onTap: ()=>Navigator.pushNamed(
                  context, AppRoutes.transactions
              ),
            ),
            ModuleMenuCard(
              title: 'Ratings Module',
              subtitle: 'Review form and rating summary',
              icon: Icons.star,
              onTap: ()=>Navigator.pushNamed(
                  context, AppRoutes.ratings
              ),
            ),
            ModuleMenuCard(
              title: 'User Profile Module',
              subtitle: 'View and edit account information',
              icon: Icons.person,
              onTap: ()=>Navigator.pushNamed(
                  context, AppRoutes.profile
              ),
            ),
          ],
        ),
      ),
    );
  }
}