import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget _bar(double height) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freelancer dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Card(
              child: ListTile(
                leading: Icon(Icons.auto_graph_rounded),
                title: Text('Analytics charts'),
                subtitle: Text('Advanced feature placeholder for fl_chart earnings and ratings visualization'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Earnings overview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(70),
                          const SizedBox(width: 12),
                          _bar(110),
                          const SizedBox(width: 12),
                          _bar(95),
                          const SizedBox(width: 12),
                          _bar(140),
                          const SizedBox(width: 12),
                          _bar(120),
                          const SizedBox(width: 12),
                          _bar(160),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Last 6 months earnings trend', style: TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
