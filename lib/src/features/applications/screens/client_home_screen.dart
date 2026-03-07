import 'package:flutter/material.dart';
import '../../../widgets/app_widgets.dart';
import '../data/mock_data.dart';

class ClientHomeScreen extends StatelessWidget {
  final VoidCallback? onBecomeFreelancer;

  const ClientHomeScreen({
    super.key,
    this.onBecomeFreelancer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        isFreelancer: false,
        onBecomeFreelancer: onBecomeFreelancer,
      ),
      appBar: AppBar(
        title: const Text('Client Home', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SearchHeader(
            hint: 'Search freelancers or services',
            title: 'Hire faster',
            subtitle: 'Post jobs, compare services, and manage project orders.',
          ),
          const SizedBox(height: 18),
          const StatsRow(items: MockData.clientStats),
          const SizedBox(height: 18),
          const FeatureBanner(
            title: 'Client tools',
            subtitle: 'Camera proof, real-time applications, milestone approvals, and review tracking.',
            icon: Icons.business_center_rounded,
          ),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Quick actions'),
          const SizedBox(height: 12),
          const ActionGrid(
            icons: [
              Icons.add_box_rounded,
              Icons.storefront_rounded,
              Icons.people_alt_rounded,
              Icons.rate_review_rounded
            ],
            labels: ['Post Job', 'Browse Services', 'Applications', 'Reviews'],
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Recent job requests'),
          const SizedBox(height: 12),
          ...MockData.jobs.map((e) => JobCard(item: e)),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Recommended services'),
          const SizedBox(height: 12),
          ...MockData.services.map((e) => ServiceCard(item: e)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () => Navigator.pushNamed(context, '/createPost'),
        label: const Text('Post Job'),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }
}
