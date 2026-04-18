import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../state/app_state.dart';

/// Analytics dashboard for a freelancer (or any reviewee).
///
/// Sections:
/// 1. KPI summary card — avg rating, total reviews, completed projects.
/// 2. Monthly earnings bar chart (last 6 months).
/// 3. Rating trend line chart (monthly avg rating over time).
/// 4. Rating distribution pie chart with legend.
///
/// Accessible via ProfilePage → "View Earnings & Stats" or from the
/// Reviews hub → "My Stats" button.
class FreelancerStatsPage extends StatefulWidget {
  const FreelancerStatsPage({super.key, required this.freelancerId});
  final String freelancerId;

  @override
  State<FreelancerStatsPage> createState() => _FreelancerStatsPageState();
}

class _FreelancerStatsPageState extends State<FreelancerStatsPage> {
  Map<String, double> _monthlyEarnings = {};
  Map<int, int> _ratingDistribution = {};
  Map<String, double> _ratingTrend = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final earnings =
        await AppState.instance.getMonthlyEarnings(widget.freelancerId);
    final dist =
        await AppState.instance.getRatingDistribution(widget.freelancerId);
    final trend =
        await AppState.instance.getMonthlyRatingTrend(widget.freelancerId);
    if (mounted) {
      setState(() {
        _monthlyEarnings = earnings;
        _ratingDistribution = dist;
        _ratingTrend = trend;
        _loading = false;
      });
    }
  }

  Future<void> _shareProfile() async {
    final user = AppState.instance.users
        .where((u) => u.uid == widget.freelancerId)
        .firstOrNull;
    final name = user?.displayName ?? 'this freelancer';
    final avgRating =
        user?.averageRating?.toStringAsFixed(1) ?? '—';
    final totalReviews = user?.totalReviews ?? 0;
    final skills = user?.skills.take(5).join(', ') ?? '';

    await Share.share(
      'Check out $name on FreelanceHub!\n'
      '⭐ Rating: $avgRating/5 ($totalReviews reviews)\n'
      '🛠 Skills: $skills\n\n'
      'https://freelancehub.app/profile/${widget.freelancerId}',
      subject: '$name — FreelanceHub Profile',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.users
        .where((u) => u.uid == widget.freelancerId)
        .firstOrNull;
    final completedProjects = AppState.instance.projects
        .where((p) =>
            p.isCompleted &&
            (p.freelancerId == widget.freelancerId ||
                p.clientId == widget.freelancerId))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${user?.displayName ?? 'Freelancer'} — Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Profile',
            onPressed: _shareProfile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── KPI summary ──────────────────────────────────────
                    if (user != null) _KpiCard(user: user, completedProjects: completedProjects),
                    const SizedBox(height: 20),

                    // ── Monthly earnings bar chart ─────────────────────
                    _SectionHeader(
                        icon: Icons.payments_outlined,
                        title: 'Monthly Earnings (Last 6 Months)'),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                        child: _monthlyEarnings.isEmpty
                            ? _EmptyChartPlaceholder(
                                message: 'No earnings data yet.')
                            : SizedBox(
                                height: 200,
                                child: _EarningsBarChart(
                                    data: _monthlyEarnings),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Rating trend line chart ─────────────────────────
                    _SectionHeader(
                        icon: Icons.show_chart,
                        title: 'Rating Trend'),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                        child: _ratingTrend.isEmpty
                            ? _EmptyChartPlaceholder(
                                message: 'No rating data yet.')
                            : SizedBox(
                                height: 200,
                                child: _RatingLineChart(
                                    data: _ratingTrend),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Rating distribution pie chart ──────────────────
                    _SectionHeader(
                        icon: Icons.pie_chart_outline,
                        title: 'Rating Distribution'),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _ratingDistribution.isEmpty ||
                                _ratingDistribution.values
                                    .every((v) => v == 0)
                            ? _EmptyChartPlaceholder(
                                message: 'No ratings yet.')
                            : SizedBox(
                                height: 220,
                                child: _RatingPieChart(
                                    data: _ratingDistribution),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── KPI summary card ──────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.user, required this.completedProjects});
  final dynamic user; // ProfileUser
  final int completedProjects;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _KpiItem(
              value: user.averageRating?.toStringAsFixed(1) ?? '—',
              label: 'Avg Rating',
              icon: Icons.star_rounded,
              iconColor: Colors.amber,
            ),
            _Divider(),
            _KpiItem(
              value: '${user.totalReviews ?? 0}',
              label: 'Reviews',
              icon: Icons.rate_review_outlined,
              iconColor: cs.primary,
            ),
            _Divider(),
            _KpiItem(
              value: '$completedProjects',
              label: 'Completed',
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  const _KpiItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        width: 1,
        color: Colors.black12,
      );
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(title,
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Empty placeholder ─────────────────────────────────────────────────────────

class _EmptyChartPlaceholder extends StatelessWidget {
  const _EmptyChartPlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Center(
          child: Text(message,
              style: const TextStyle(color: Colors.grey)),
        ),
      );
}

// ── Earnings bar chart ────────────────────────────────────────────────────────

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
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              'RM ${rod.toY.toStringAsFixed(0)}',
              const TextStyle(color: Colors.white),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (v, _) => Text(
                'RM ${v.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(entries[i].key,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.grey)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: Theme.of(context).colorScheme.primary,
                width: 18,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Rating trend line chart ───────────────────────────────────────────────────

class _RatingLineChart extends StatelessWidget {
  const _RatingLineChart({required this.data});
  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = data.entries.toList();
    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 5.5,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cs.primary,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: cs.primary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots
                .map((s) => LineTooltipItem(
                      s.y.toStringAsFixed(1),
                      const TextStyle(color: Colors.white),
                    ))
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    entries[i].key,
                    style: const TextStyle(
                        fontSize: 9, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.black12, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

// ── Rating distribution pie chart ─────────────────────────────────────────────

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
        const SizedBox(width: 16),
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
                  Icon(Icons.star_rounded,
                      color: colors[i], size: 14),
                  const SizedBox(width: 4),
                  Text('$star star${star == 1 ? '' : 's'}: $count',
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
