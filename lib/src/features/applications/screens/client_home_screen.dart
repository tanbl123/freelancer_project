import 'package:flutter/material.dart';
import '../../../widgets/app_widgets.dart';
import '../data/mock_data.dart';

class ClientHomeScreen extends StatelessWidget {
  final VoidCallback? onBecomeFreelancer;

  const ClientHomeScreen({
    super.key,
    this.onBecomeFreelancer,
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
        isFreelancer: false,
        onBecomeFreelancer: onBecomeFreelancer,
      ),
      appBar: AppBar(
        title: const Text('Client Home', style: TextStyle(fontWeight: FontWeight.w800)),
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

          Row(
            children: [
              _quickButton(
                context: context,
                icon: Icons.add_box_rounded,
                label: 'Post Job',
                route: '/createPost',
              ),
              const SizedBox(width: 12),
              _quickButton(
                context: context,
                icon: Icons.storefront_rounded,
                label: 'Browse Services',
                route: '/serviceDetail',
              ),
              const SizedBox(width: 12),
              _quickButton(
                context: context,
                icon: Icons.people_alt_rounded,
                label: 'Applications',
                route: '/applications',
              ),
              const SizedBox(width: 12),
              _quickButton(
                context: context,
                icon: Icons.rate_review_rounded,
                label: 'Reviews',
                route: '/reviewList',
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
                  label: const Text('My Posts'),
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