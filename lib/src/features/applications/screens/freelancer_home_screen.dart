import 'package:flutter/material.dart';
import '../../../widgets/app_widgets.dart';
import '../data/mock_data.dart';

class FreelancerHomeScreen extends StatelessWidget {
  final VoidCallback? onSwitchToClient;

  const FreelancerHomeScreen({
    super.key,
    this.onSwitchToClient,
  });

  Widget _quickButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE0E7FF),
                child: Icon(icon, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        isFreelancer: true,
        onSwitchToClient: onSwitchToClient,
      ),
      appBar: AppBar(
        title: const Text('Freelancer Home', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/chatList'),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/applications'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SearchHeader(
            hint: 'Search jobs, categories, or skills',
            title: 'Find your next project',
            subtitle: 'Browse jobs, send proposals, manage milestones, and grow earnings.',
          ),
          const SizedBox(height: 18),
          const StatsRow(items: MockData.freelancerStats),
          const SizedBox(height: 18),
          const FeatureBanner(
            title: 'Freelancer tools',
            subtitle: 'Offline job cache, voice pitch, signature approval, analytics charts, and sharing.',
            icon: Icons.workspace_premium_rounded,
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Quick actions'),
          const SizedBox(height: 12),

          Row(
            children: [
              _quickButton(
                context: context,
                icon: Icons.search_rounded,
                label: 'Find Jobs',
                route: '/jobDetail',
              ),
              const SizedBox(width: 12),
              _quickButton(
                context: context,
                icon: Icons.add_business_rounded,
                label: 'Create Service',
                route: '/createPost',
              ),
              const SizedBox(width: 12),
              _quickButton(
                context: context,
                icon: Icons.description_rounded,
                label: 'Proposal',
                route: '/applicationForm',
              ),
              const SizedBox(width: 12),
              _quickButton(
                context: context,
                icon: Icons.bar_chart_rounded,
                label: 'Dashboard',
                route: '/dashboard',
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/myPosts'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('My Services'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/chatList'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Messages'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const SectionTitle(title: 'Latest jobs'),
          const SizedBox(height: 12),
          ...MockData.jobs.map((e) => JobCard(item: e)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () => Navigator.pushNamed(context, '/createPost'),
        label: const Text('Create Service'),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }
}