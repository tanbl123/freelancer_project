import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/service_order.dart';

/// Shows all service orders for the current user.
///
/// - **Client view**: orders they submitted; can Cancel pending ones.
/// - **Freelancer view**: orders received; can Accept / Reject pending ones.
///
/// Uses [StreamBuilder] for real-time updates via Supabase Realtime.
class ServiceOrdersPage extends StatefulWidget {
  const ServiceOrdersPage({super.key});

  @override
  State<ServiceOrdersPage> createState() => _ServiceOrdersPageState();
}

class _ServiceOrdersPageState extends State<ServiceOrdersPage> {
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChanged);
    AppState.instance.reloadServiceOrders();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isFreelancer = user?.role == UserRole.freelancer;
    final orders = AppState.instance.serviceOrders;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              isFreelancer
                  ? 'No service orders received yet.'
                  : 'You haven\'t placed any service orders yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: AppState.instance.reloadServiceOrders,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: orders.length,
        itemBuilder: (ctx, i) => _ServiceOrderCard(
          order: orders[i],
          isFreelancerView: isFreelancer,
        ),
      ),
    );
  }
}

// ── Service order card ─────────────────────────────────────────────────────

class _ServiceOrderCard extends StatefulWidget {
  const _ServiceOrderCard({
    required this.order,
    required this.isFreelancerView,
  });
  final ServiceOrder order;
  final bool isFreelancerView;

  @override
  State<_ServiceOrderCard> createState() => _ServiceOrderCardState();
}

class _ServiceOrderCardState extends State<_ServiceOrderCard> {
  bool _loading = false;

  // ── Action helpers ─────────────────────────────────────────────────────────

  Future<void> _doAction(Future<String?> Function() fn,
      String successMsg) async {
    setState(() => _loading = true);
    final err = await fn();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? successMsg)));
  }

  void _handleCancel() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Cancel this service order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _doAction(
                () => AppState.instance
                    .cancelServiceOrder(widget.order),
                'Order cancelled.',
              );
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  void _handleAccept() {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Accept "${widget.order.serviceTitle}" order from '
                '${widget.order.clientName}?\n\n'
                'A project will be created automatically.'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. Looking forward to working with you!',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _doAction(
                () => AppState.instance
                    .acceptServiceOrder(widget.order, noteCtrl.text),
                'Order accepted! Project created.',
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _handleReject() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Decline this order? The client will be notified.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. Fully booked at the moment.',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _doAction(
                () => AppState.instance
                    .rejectServiceOrder(widget.order, reasonCtrl.text),
                'Order rejected.',
              );
            },
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusColor = order.status.color;
    final dateStr = order.createdAt != null
        ? DateFormat('d MMM y').format(order.createdAt!)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ───────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.design_services_outlined,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.serviceTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                                overflow: TextOverflow.ellipsis),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/profile/view',
                                arguments: widget.isFreelancerView
                                    ? order.clientId
                                    : order.freelancerId,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.isFreelancerView
                                        ? 'From: ${order.clientName}'
                                        : 'To: ${order.freelancerName}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(width: 2),
                                  const Text('›',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          order.status.displayName.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Message ──────────────────────────────────────────
                  Text(order.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 8),

                  // ── Details row ──────────────────────────────────────
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (order.proposedBudget != null)
                        _Detail(
                          icon: Icons.attach_money,
                          label:
                              'RM ${order.proposedBudget!.toStringAsFixed(0)}',
                        ),
                      if (order.timelineDays != null)
                        _Detail(
                          icon: Icons.schedule_outlined,
                          label: '${order.timelineDays} days',
                        ),
                      if (dateStr.isNotEmpty)
                        _Detail(
                          icon: Icons.calendar_today_outlined,
                          label: dateStr,
                        ),
                    ],
                  ),

                  // ── Freelancer note (on accept/reject) ───────────────
                  if (order.freelancerNote != null &&
                      order.freelancerNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.comment_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '"${order.freelancerNote}"',
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Action buttons ───────────────────────────────────
                  if (order.isPending) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.isFreelancerView) ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red),
                            onPressed: _handleReject,
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Accept'),
                            onPressed: _handleAccept,
                          ),
                        ] else ...[
                          TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined,
                                size: 16),
                            label: const Text('Cancel'),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            onPressed: _handleCancel,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
