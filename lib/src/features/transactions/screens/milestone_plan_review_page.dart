import 'package:flutter/material.dart';

import '../../../state/app_state.dart';
import '../../payment/screens/checkout_screen.dart';
import '../models/milestone_item.dart';
import '../models/project_item.dart';

/// Client reviews the freelancer's proposed milestone plan and either
/// approves it (project → inProgress) or rejects it (milestones deleted,
/// freelancer can re-propose).
class MilestonePlanReviewPage extends StatefulWidget {
  const MilestonePlanReviewPage({
    super.key,
    required this.project,
    required this.milestones,
  });

  final ProjectItem project;
  final List<MilestoneItem> milestones;

  @override
  State<MilestonePlanReviewPage> createState() =>
      _MilestonePlanReviewPageState();
}

class _MilestonePlanReviewPageState extends State<MilestonePlanReviewPage> {
  bool _loading = false;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Approve (pay first, then approve) ─────────────────────────────────────

  Future<void> _approve() async {
    // Step 1 — Client must pay (hold in escrow) BEFORE the plan is approved.
    // If they go back without paying, nothing is approved.
    final paymentDone = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          project: widget.project,
          milestones: widget.milestones,
        ),
      ),
    );
    if (paymentDone != true || !mounted) return; // user cancelled — do nothing

    // Step 2 — Payment succeeded → now approve the plan.
    setState(() => _loading = true);
    final err = await AppState.instance.approveMilestonePlan(
      widget.project,
      widget.milestones,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Payment secured & plan approved! Freelancer has been notified to start.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
    Navigator.pop(context, 'approved');
  }

  // ── Reject ─────────────────────────────────────────────────────────────────

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Milestone Plan'),
        content: const Text(
          'All proposed milestones will be removed and the freelancer will '
          'need to submit a revised plan.\n\nContinue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Plan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final err = await AppState.instance.rejectMilestonePlan(
      widget.project,
      widget.milestones,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Plan rejected. Freelancer will revise.')),
      );
      Navigator.pop(context, 'rejected');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sorted = List<MilestoneItem>.from(widget.milestones)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final budget = widget.project.totalBudget ?? 0;
    final totalPct = sorted.fold(0.0, (s, m) => s + m.percentage);

    return Scaffold(
      appBar: AppBar(title: const Text('Review Milestone Plan')),
      body: Column(
        children: [
          // ── Payment-required notice ──────────────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.amber.shade50,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment is required to approve this plan. '
                    'Funds are held in escrow until each milestone is completed.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),

          // ── Summary header ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.project.jobTitle ?? 'Project Review',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      budget > 0
                          ? 'Total Budget: RM ${budget.toStringAsFixed(2)}'
                          : 'Budget not set',
                    ),
                    const Spacer(),
                    Text(
                      '${sorted.length} milestones · '
                      '${totalPct.toStringAsFixed(0)}% allocated',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Milestone list ───────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: sorted.length,
              itemBuilder: (ctx, i) {
                final m = sorted[i];
                final amount =
                    budget > 0 ? budget * m.percentage / 100 : m.paymentAmount;
                final isFirst = i == 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: isFirst
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.grey.shade200,
                              child: Text(
                                '${m.orderIndex}',
                                style: TextStyle(
                                  color: isFirst
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                m.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${m.percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color:
                                      Theme.of(ctx).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          m.description,
                          style: const TextStyle(
                              color: Colors.black87, height: 1.4),
                        ),
                        const SizedBox(height: 10),

                        // Amount + deadline row
                        Row(
                          children: [
                            const Icon(Icons.attach_money,
                                size: 16, color: Colors.green),
                            Text(
                              'RM ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.calendar_today,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              _fmt(m.deadline),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),

                        // "Starts first" badge
                        if (isFirst) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.green.shade200),
                            ),
                            child: const Text(
                              'Freelancer starts after payment is secured',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Action buttons ───────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject Plan'),
                      onPressed: _reject,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                      icon: const Icon(Icons.payment),
                      label: const Text('Pay & Approve'),
                      onPressed: _approve,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
