import 'package:flutter/material.dart';
import '../../../widgets/app_widgets.dart';
import '../data/mock_data.dart';

class FreelancerHomeScreen extends StatelessWidget {
  final VoidCallback? onSwitchToClient;

  const FreelancerHomeScreen({
    super.key,
    this.onSwitchToClient,
  });

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
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
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
          const ActionGrid(
            icons: [
              Icons.search_rounded,
              Icons.add_business_rounded,
              Icons.description_rounded,
              Icons.bar_chart_rounded
            ],
            labels: ['Find Jobs', 'Create Service', 'My Proposals', 'Dashboard'],
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
