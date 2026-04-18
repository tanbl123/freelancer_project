import 'package:flutter/material.dart';

import '../../../../shared/enums/dispute_status.dart';
import '../../../../state/app_state.dart';
import '../../models/dispute_record.dart';
import 'admin_dispute_review_screen.dart';

/// Admin-only screen listing all disputes, grouped by status tab.
class AdminDisputeListScreen extends StatefulWidget {
  const AdminDisputeListScreen({super.key});

  @override
  State<AdminDisputeListScreen> createState() => _AdminDisputeListScreenState();
}

class _AdminDisputeListScreenState extends State<AdminDisputeListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;

  static const _tabLabels = ['Open', 'Under Review', 'Resolved', 'Closed'];
  static const _tabStatuses = [
    DisputeStatus.open,
    DisputeStatus.underReview,
    DisputeStatus.resolved,
    DisputeStatus.closed,
  ];

  List<DisputeRecord> _disputes = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabLabels.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _disputes = await AppState.instance.loadAllDisputesForAdmin();
    if (mounted) setState(() => _loading = false);
  }

  List<DisputeRecord> _byStatus(DisputeStatus s) =>
      _disputes.where((d) => d.status == s).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar row with inline refresh button
        Row(
          children: [
            Expanded(
              child: TabBar(
                controller: _tabCtrl,
                tabs: _tabLabels
                    .asMap()
                    .entries
                    .map((e) {
                      final count = _byStatus(_tabStatuses[e.key]).length;
                      return Tab(
                        text: count > 0 ? '${e.value} ($count)' : e.value,
                      );
                    })
                    .toList(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabCtrl,
                  children: _tabStatuses
                      .map((s) => _DisputeListView(
                            disputes: _byStatus(s),
                            onRefresh: _load,
                            onTap: (d) async {
                              await Navigator.of(context)
                                  .push(MaterialPageRoute(
                                builder: (_) =>
                                    AdminDisputeReviewScreen(dispute: d),
                              ));
                              await _load();
                            },
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _DisputeListView extends StatelessWidget {
  const _DisputeListView({
    required this.disputes,
    required this.onRefresh,
    required this.onTap,
  });

  final List<DisputeRecord> disputes;
  final Future<void> Function() onRefresh;
  final void Function(DisputeRecord) onTap;

  @override
  Widget build(BuildContext context) {
    if (disputes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No disputes in this category',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: disputes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _DisputeCard(
          dispute: disputes[i],
          onTap: () => onTap(disputes[i]),
        ),
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.dispute, required this.onTap});

  final DisputeRecord dispute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final statusColor = _statusColor(dispute.status);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dispute.reason.displayName,
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _StatusBadge(status: dispute.status, color: statusColor),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dispute.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    dispute.isRaisedByClient ? Icons.person : Icons.engineering,
                    size: 14,
                    color: cs.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'By ${dispute.isRaisedByClient ? 'client' : 'freelancer'}',
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                  const Spacer(),
                  Text(
                    _fmt(dispute.createdAt),
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
              if (dispute.hasEvidence)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, size: 13, color: cs.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${dispute.evidenceUrls.length} evidence link(s)',
                        style: tt.labelSmall?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(DisputeStatus s) => switch (s) {
        DisputeStatus.open        => Colors.orange,
        DisputeStatus.underReview => Colors.blue,
        DisputeStatus.resolved    => Colors.green,
        DisputeStatus.closed      => Colors.grey,
      };

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final DisputeStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
