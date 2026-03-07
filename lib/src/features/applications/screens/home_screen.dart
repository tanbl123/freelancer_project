import 'package:flutter/material.dart';
import '../data/app_data.dart';
import '../../../common_widgets/common_widgets.dart';
import 'create_post_screen.dart';
import 'job_detail_screen.dart';
import 'service_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marketplace'),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_outlined)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Job Requests'),
              Tab(text: 'Service Offers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const FeatureBanner(
                  title: 'Offline Job Feed Cache',
                  subtitle: 'Latest 20 jobs can load from SQLite when internet is unavailable.',
                  icon: Icons.cloud_off_outlined,
                ),
                const SizedBox(height: 12),
                ...AppData.jobs.map(
                  (job) => JobCard(
                    job: job,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
                    ),
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...AppData.services.map(
                  (service) => ServiceCard(
                    service: service,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: service)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
