import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../state/app_state.dart';

class FreelancerStatsPage extends StatefulWidget {
  const FreelancerStatsPage({super.key, required this.freelancerId});
  final String freelancerId;

  @override
  State<FreelancerStatsPage> createState() => _FreelancerStatsPageState();
}

class _FreelancerStatsPageState extends State<FreelancerStatsPage> {
  Map<String, double> _monthlyEarnings = {};
  Map<int, int> _ratingDistribution = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final earnings =
        await AppState.instance.getMonthlyEarnings(widget.freelancerId);
    final ratings =
        await AppState.instance.getRatingDistribution(widget.freelancerId);
    if (mounted) {
      setState(() {
        _monthlyEarnings = earnings;
        _ratingDistribution = ratings;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final freelancer = AppState.instance.users
        .where((u) => u.uid == widget.freelancerId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('${freelancer?.displayName ?? 'Freelancer'} Stats'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating summary card
                  if (freelancer != null)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  freelancer.averageRating
                                          ?.toStringAsFixed(1) ??
                                      '—',
                                  style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text('Avg Rating',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54)),
                              ],
                            ),
                            const Icon(Icons.star,
                                color: Colors.amber, size: 40),
                            Column(
                              children: [
                                Text(
                                  '${freelancer.totalReviews ?? 0}',
                                  style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text('Total Reviews',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Monthly earnings bar chart
                  const Text('Monthly Earnings (Last 6 Months)',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      child: _monthlyEarnings.isEmpty
                          ? const SizedBox(
                              height: 160,
                              child: Center(
                                child: Text('No earnings data yet.',
                                    style:
                                        TextStyle(color: Colors.grey)),
                              ),
                            )
                          : SizedBox(
                              height: 200,
                              child: _EarningsBarChart(
                                  data: _monthlyEarnings),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Rating distribution pie chart
                  const Text('Rating Distribution',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _ratingDistribution.isEmpty ||
                              _ratingDistribution.values
                                  .every((v) => v == 0)
                          ? const SizedBox(
                              height: 160,
                              child: Center(
                                child: Text('No ratings yet.',
                                    style:
                                        TextStyle(color: Colors.grey)),
                              ),
                            )
                          : SizedBox(
                              height: 220,
                              child: _RatingPieChart(
                                  data: _ratingDistribution),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EarningsBarChart extends StatelessWidget {
  const _EarningsBarChart({required this.data});
  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxY = entries.isEmpty
        ? 100.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) *
            1.2;

    return BarChart(
      BarChartData(
        maxY: maxY > 0 ? maxY : 100,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                'RM ${rod.toY.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                'RM ${value.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    entries[index].key,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: Theme.of(context).colorScheme.primary,
                width: 18,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _RatingPieChart extends StatelessWidget {
  const _RatingPieChart({required this.data});
  final Map<int, int> data;

  @override
  Widget build(BuildContext context) {
    final total =
        data.values.fold<int>(0, (sum, v) => sum + v).toDouble();
    final colors = [
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.yellow.shade600,
      Colors.lightGreen.shade400,
      Colors.green.shade500,
    ];

    final sections = data.entries
        .where((e) => e.value > 0)
        .map((e) {
          final pct = total > 0 ? (e.value / total * 100) : 0.0;
          return PieChartSectionData(
            color: colors[(e.key - 1).clamp(0, 4)],
            value: e.value.toDouble(),
            title: '${pct.toStringAsFixed(0)}%',
            radius: 80,
            titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white),
            badgeWidget: Text('${e.key}★',
                style: const TextStyle(
                    fontSize: 10, color: Colors.white70)),
            badgePositionPercentageOffset: 1.3,
          );
        })
        .toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(5, (i) {
            final star = i + 1;
            final count = data[star] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.star,
                      color: colors[i], size: 14),
                  const SizedBox(width: 4),
                  Text('$star star: $count',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
