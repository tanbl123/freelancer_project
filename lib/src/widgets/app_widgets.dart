import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final bool isFreelancer;
  final VoidCallback? onBecomeFreelancer;
  final VoidCallback? onSwitchToClient;

  const AppDrawer({
    super.key,
    required this.isFreelancer,
    this.onBecomeFreelancer,
    this.onSwitchToClient,
  });

  @override
  Widget build(BuildContext context) {
    final items = isFreelancer
        ? [
            ('Home', '/freelancerHome'),
            ('Find Jobs', '/freelancerHome'),
            ('My Applications', '/applications'),
            ('Milestones', '/milestones'),
            ('Dashboard', '/dashboard'),
            ('Reviews', '/rating'),
            ('Profile', '/profile'),
            ('Switch to Client', '/switchToClient'),
          ]
        : [
            ('Home', '/clientHome'),
            ('Post Job', '/createPost'),
            ('Browse Services', '/clientHome'),
            ('Applications', '/applications'),
            ('Orders', '/milestones'),
            ('Reviews', '/rating'),
            ('Profile', '/profile'),
            ('Become a Freelancer', '/becomeFreelancer'),
          ];

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.person, color: Color(0xFF4F46E5)),
              ),
              title: Text(
                'Zi Zhang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Premium account'),
            ),
            const Divider(),
            ...items.map(
              (item) {
                final isBecomeFreelancer = item.$2 == '/becomeFreelancer';
                final isSwitchToClient = item.$2 == '/switchToClient';
                
                return ListTile(
                  leading: const Icon(Icons.chevron_right_rounded),
                  title: Text(item.$1),
                  onTap: () {
                    if (isBecomeFreelancer && onBecomeFreelancer != null) {
                      Navigator.pop(context);
                      onBecomeFreelancer!();
                    } else if (isSwitchToClient && onSwitchToClient != null) {
                      Navigator.pop(context);
                      onSwitchToClient!();
                    } else {
                      Navigator.pushNamed(context, item.$2);
                    }
                  },
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchHeader extends StatelessWidget {
  final String hint;
  final String title;
  final String subtitle;
  const SearchHeader({
    super.key,
    required this.hint,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class StatsRow extends StatelessWidget {
  final List<Map<String, String>> items;
  const StatsRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: item == items.last ? 0 : 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['value'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['title'] ?? '',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class ActionGrid extends StatelessWidget {
  final List<IconData> icons;
  final List<String> labels;
  const ActionGrid({super.key, required this.icons, required this.labels});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: labels.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .95,
      ),
      itemBuilder: (context, index) {
        return Container(
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
                child: Icon(icons[index], color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 10),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  const SectionTitle({super.key, required this.title, this.action = 'See all'});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(action, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class JobCard extends StatelessWidget {
  final Map<String, String> item;
  const JobCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.pushNamed(context, '/jobDetail'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(item['skills'] ?? '', style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 12),
              Row(
                children: [
                  _pill(item['budget'] ?? '', const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
                  const SizedBox(width: 8),
                  _pill(item['deadline'] ?? '', const Color(0xFFFEF3C7), const Color(0xFF92400E)),
                ],
              ),
              const SizedBox(height: 12),
              Text('by ${item['client'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final Map<String, String> item;
  const ServiceCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.pushNamed(context, '/serviceDetail'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.design_services_rounded, size: 34, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('${item['seller']} • ⭐ ${item['rating']}', style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    Text(item['price'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(item['tag'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const FeatureBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
