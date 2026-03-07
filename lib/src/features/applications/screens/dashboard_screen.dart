import 'package:flutter/material.dart';

import '../../../common_widgets/common_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bars = [1200.0, 1500.0, 1100.0, 1800.0, 2000.0, 1750.0];
    final months = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
    return Scaffold(
      appBar: AppBar(title: const Text('Freelancer Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              Expanded(child: StatCard(title: 'Avg Rating', value: '4.9', icon: Icons.star_outline)),
              SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Projects', value: '28', icon: Icons.work_outline)),
            ],
          ),
          const SizedBox(height: 12),
          const FeatureBanner(
            title: 'Interactive Data Visualization',
            subtitle: 'Replace this custom chart with fl_chart in your final assignment.',
            icon: Icons.pie_chart_outline,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Earnings (Last 6 Months)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 220,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(bars.length, (index) {
                      final normalizedHeight = (bars[index] / 2000) * 160;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('RM ${bars[index].toInt()}'),
                          const SizedBox(height: 8),
                          Container(
                            width: 28,
                            height: normalizedHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF345CFF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(months[index]),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.share_outlined),
                const SizedBox(width: 12),
                const Expanded(child: Text('Share Profile using native mobile sharing menu.')),
                FilledButton.tonal(onPressed: () {}, child: const Text('Share')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
