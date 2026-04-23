import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';
import '../../transactions/models/milestone_item.dart';
import '../../transactions/models/project_item.dart';
import '../models/overdue_record.dart';
import '../services/overdue_service.dart';

/// Displays all active projects with overdue or warning milestones.
///
/// Available to both clients and freelancers; each only sees their own projects.
/// Admins see all. Accessible from [AppRoutes.overdueDashboard].
class OverdueDashboardScreen extends StatefulWidget {
  const OverdueDashboardScreen({super.key});

  @override
  State<OverdueDashboardScreen> createState() =>
      _OverdueDashboardScreenState();
}

class _OverdueDashboardScreenState
    extends State<OverdueDashboardScreen> {
  List<_OverdueItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final user = AppState.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final projects = AppState.instance.projects.where(
      (p) =>
          p.isInProgress &&
          (user.role == UserRole.admin ||
              p.clientId == user.uid ||
              p.freelancerId == user.uid),
    );

    final items = <_OverdueItem>[];
    for (final project in projects) {
      final milestones =
          await AppState.instance.getMilestonesForProject(project.id);
      final records = await AppState.instance
          .loadOverdueRecordsForProject(project.id);

      for (final m in milestones.where((m) => m.isInProgress)) {
        final status = OverdueService.computeWarningStatus(m);
        if (status == OverdueStatus.onTrack) continue;

        final record = records
            .where((r) => r.milestoneId == m.id)
            .firstOrNull;

        items.add(_OverdueItem(
          project: project,
          milestone: m,
          status: status,
          record: record,
        ));
      }
    }

    // Sort: most severe first, then earliest deadline
    items.sort((a, b) {
      final sev = b.status.index.compareTo(a.status.index);
      if (sev != 0) return sev;
      return a.milestone.effectiveDeadline
          .compareTo(b.milestone.effectiveDeadline);
    });

    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overdue Overview'),
        actions: [
          // DEV: force an immediate overdue check then refresh the list.
          IconButton(
            tooltip: 'Run overdue check now',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () async {
              AppState.instance.startOverdueChecker();
              // Give the check a moment to complete before reloading the list.
              await Future.delayed(const Duration(seconds: 3));
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) => _OverdueCard(
                      item: _items[i],
                      onView: () => Navigator.pushNamed(
                        context,
                        AppRoutes.transactions,
                        arguments: _items[i].project.id,
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green.shade300),
            const SizedBox(height: 12),
            const Text(
              'All milestones are on track!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
}

// ── Data carrier ─────────────────────────────────────────────────────────────

class _OverdueItem {
  const _OverdueItem({
    required this.project,
    required this.milestone,
    required this.status,
    this.record,
  });
  final ProjectItem project;
  final MilestoneItem milestone;
  final OverdueStatus status;
  final OverdueRecord? record;
}

// ── Card widget ──────────────────────────────────────────────────────────────

class _OverdueCard extends StatelessWidget {
  const _OverdueCard({required this.item, required this.onView});
  final _OverdueItem item;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final color = item.status.color;
    final daysLeft = OverdueService.daysUntilDeadline(item.milestone);
    final label = OverdueService.deadlineLabel(item.milestone);
    final isEnforced = item.status == OverdueStatus.triggered;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status badge row ─────────────────────────────────────────
            Row(
              children: [
                Icon(item.status.icon, color: color, size: 18),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    item.status.displayName.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  label,
                  style: TextStyle(
                    color: daysLeft < 0 ? Colors.red : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Project & milestone ──────────────────────────────────────
            Text(
              item.project.jobTitle ?? 'Project',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.flag_outlined,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Milestone ${item.milestone.orderIndex}: ${item.milestone.title}',
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Deadline row ─────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _fmtDate(item.milestone.effectiveDeadline),
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 13),
                ),
                if (item.milestone.extensionApproved) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      '+${item.milestone.extensionDays}d extended',
                      style: const TextStyle(
                          color: Colors.blue, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),

            // ── Warning timestamps ───────────────────────────────────────
            if (item.record != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _WarningTimeline(record: item.record!),
            ],

            // ── Enforcement notice ───────────────────────────────────────
            if (isEnforced) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  '🚫 Enforcement applied: project cancelled, '
                  'freelancer restricted, escrow refunded.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── View button ──────────────────────────────────────────────
            if (!isEnforced)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View Project'),
                  onPressed: onView,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Warning timeline sub-widget ──────────────────────────────────────────────

class _WarningTimeline extends StatelessWidget {
  const _WarningTimeline({required this.record});
  final OverdueRecord record;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        label: '3-day warning',
        sentAt: record.warningFirstSentAt,
        color: Colors.orange,
      ),
      (
        label: '1-day warning',
        sentAt: record.warningSecondSentAt,
        color: Colors.deepOrange,
      ),
      (
        label: 'Final warning',
        sentAt: record.finalWarningAt,
        color: Colors.red,
      ),
      (
        label: 'Enforcement',
        sentAt: record.triggeredAt,
        color: const Color(0xFF8B0000),
      ),
    ];

    return Column(
      children: steps.map((s) {
        final sent = s.sentAt != null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                sent ? Icons.check_circle : Icons.radio_button_unchecked,
                color: sent ? s.color : Colors.grey.shade300,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                s.label,
                style: TextStyle(
                  fontSize: 11,
                  color: sent ? s.color : Colors.grey,
                  fontWeight:
                      sent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (sent && s.sentAt != null) ...[
                const Spacer(),
                Text(
                  '${s.sentAt!.day}/${s.sentAt!.month}/${s.sentAt!.year}',
                  style: const TextStyle(
                      fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
