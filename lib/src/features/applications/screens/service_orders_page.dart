import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/service_order.dart';
import 'service_order_form_page.dart';

/// Shows all service orders for the current user.
///
/// - **Client view**: orders they submitted; can Cancel pending ones.
/// - **Freelancer view**: orders received; can Accept / Reject pending ones.
///
/// Uses [ListenableBuilder] backed by [AppState] (a [ChangeNotifier]).
/// The UI rebuilds automatically whenever [AppState.notifyListeners] fires —
/// triggered by user actions (accept/reject) or by the 30-second background
/// polling timer, so updates appear without a manual pull-to-refresh.
class ServiceOrdersPage extends StatefulWidget {
  const ServiceOrdersPage({super.key});

  @override
  State<ServiceOrdersPage> createState() => _ServiceOrdersPageState();
}

class _ServiceOrdersPageState extends State<ServiceOrdersPage> {
  // true = Active (pending + accepted), false = Closed (terminal statuses)
  bool _showActive = true;

  // Sub-filter for the Closed tab; null = show all closed
  ServiceOrderStatus? _closedFilter;

  @override
  void initState() {
    super.initState();
    // Populate the in-memory cache for the initial render.
    AppState.instance.reloadServiceOrders();
    // Refresh notification badge whenever this tab is opened.
    AppState.instance.loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.currentUser;
        final isFreelancer = user?.role == UserRole.freelancer;
        final orders = AppState.instance.serviceOrders;

    // Active = pending or accepted (user can still act on these)
    final activeOrders =
        orders.where((o) => !o.status.isTerminal).toList();

    // Closed = rejected, cancelled, convertedToProject
    final closedOrders =
        orders.where((o) => o.status.isTerminal).toList();

    // Apply status sub-filter inside Closed tab
    final shownClosed = _closedFilter == null
        ? closedOrders
        : closedOrders.where((o) => o.status == _closedFilter).toList();

    final shown = _showActive ? activeOrders : shownClosed;

        return RefreshIndicator(
      onRefresh: AppState.instance.reloadServiceOrders,
      child: Column(
        children: [
          // ── Active / Closed toggle ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Active',
                    count: activeOrders.length,
                    selected: _showActive,
                    onTap: () => setState(() => _showActive = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TabButton(
                    label: 'Closed',
                    count: closedOrders.length,
                    selected: !_showActive,
                    onTap: () => setState(() {
                      _showActive = false;
                      _closedFilter = null;
                    }),
                  ),
                ),
              ],
            ),
          ),

          // ── Status sub-filter chips (Closed tab only) ───────────────────
          if (!_showActive && closedOrders.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _StatusFilterChip(
                    label: 'All',
                    selected: _closedFilter == null,
                    onTap: () => setState(() => _closedFilter = null),
                  ),
                  _StatusFilterChip(
                    label: 'Rejected',
                    selected: _closedFilter == ServiceOrderStatus.rejected,
                    color: Colors.red,
                    onTap: () => setState(
                        () => _closedFilter = ServiceOrderStatus.rejected),
                  ),
                  _StatusFilterChip(
                    label: 'Cancelled',
                    selected: _closedFilter == ServiceOrderStatus.cancelled,
                    color: Colors.grey,
                    onTap: () => setState(
                        () => _closedFilter = ServiceOrderStatus.cancelled),
                  ),
                  _StatusFilterChip(
                    label: 'Accepted',
                    selected:
                        _closedFilter == ServiceOrderStatus.convertedToProject,
                    color: Colors.green,
                    onTap: () => setState(() =>
                        _closedFilter = ServiceOrderStatus.convertedToProject),
                  ),
                  _StatusFilterChip(
                    label: 'Completed',
                    selected:
                        _closedFilter == ServiceOrderStatus.completed,
                    color: Colors.teal,
                    onTap: () => setState(
                        () => _closedFilter = ServiceOrderStatus.completed),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showActive
                              ? Icons.inbox_outlined
                              : Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _showActive
                              ? (isFreelancer
                                  ? 'No active orders yet.'
                                  : 'No active orders placed yet.')
                              : (_closedFilter != null
                                  ? 'No ${_closedFilter!.displayName.toLowerCase()} orders.'
                                  : 'No closed orders yet.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: shown.length,
                    itemBuilder: (ctx, i) => _ServiceOrderCard(
                      order: shown[i],
                      isFreelancerView: isFreelancer,
                    ),
                  ),
          ),
        ],
      ),
        ); // RefreshIndicator
      },
    ); // ListenableBuilder
  }
}

// ── Active / Closed tab button (reuses same style as job applications page) ──

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.onPrimary.withValues(alpha: 0.25)
                      : cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? cs.onPrimary : cs.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Horizontal status filter chip ─────────────────────────────────────────────

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = color ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.15)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? activeColor
                  : cs.outline.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? activeColor : cs.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
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

  // ── Freelancer: show full order details in a bottom sheet ─────────────────

  void _showOrderDetail() {
    final order = widget.order;
    final dateStr = order.createdAt != null
        ? DateFormat('d MMM y, h:mm a').format(order.createdAt!)
        : '';
    final statusColor = order.status.color;

    // Live name lookup so renames are reflected immediately.
    final clientName =
        AppState.instance.users
            .where((u) => u.uid == order.clientId)
            .firstOrNull
            ?.displayName ??
        order.clientName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            // ── Drag handle ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      order.serviceTitle,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      order.status.displayName.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            // ── Scrollable content ──────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // From client
                  _SheetRow(
                    icon: Icons.person_outline,
                    label: 'Client',
                    value: clientName,
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(
                          context,
                          '/profile/view',
                          arguments: order.clientId,
                        );
                      },
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('View Profile'),
                    ),
                  ),
                  if (dateStr.isNotEmpty)
                    _SheetRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Submitted',
                      value: dateStr,
                    ),
                  if (order.proposedBudget != null)
                    _SheetRow(
                      icon: Icons.attach_money,
                      label: 'Proposed Price',
                      value: 'RM ${order.proposedBudget!.toStringAsFixed(0)}',
                      valueColor: Colors.green.shade700,
                    ),
                  if (order.timelineDays != null)
                    _SheetRow(
                      icon: Icons.schedule_outlined,
                      label: 'Expected Timeline',
                      value: '${order.timelineDays} days',
                    ),
                  const SizedBox(height: 12),
                  // Full request message
                  Text(
                    'What they need',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.message,
                      style: const TextStyle(height: 1.55, fontSize: 14),
                    ),
                  ),
                  // Freelancer note if any
                  if (order.freelancerNote != null &&
                      order.freelancerNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Your Note',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        '"${order.freelancerNote}"',
                        style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blue.shade800,
                            height: 1.4),
                      ),
                    ),
                  ],
                  // Pending actions
                  if (order.isPending) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleReject();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Accept'),
                            style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleAccept();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceOrderFormPage(existing: widget.order),
      ),
    ).then((saved) {
      if (saved == true) AppState.instance.reloadServiceOrders();
    });
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

    // Live name lookups so renames show immediately on both views.
    final clientName =
        AppState.instance.users
            .where((u) => u.uid == order.clientId)
            .firstOrNull
            ?.displayName ??
        order.clientName;
    final freelancerName =
        AppState.instance.users
            .where((u) => u.uid == order.freelancerId)
            .firstOrNull
            ?.displayName ??
        order.freelancerName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : InkWell(
              // Tapping the card opens:
              //  - Freelancer → full order detail sheet (what client requested)
              //  - Client & pending → edit form
              //  - Client & non-pending → freelancer's profile
              onTap: widget.isFreelancerView
                  ? _showOrderDetail
                  : order.isPending
                      ? _handleEdit
                      : () => Navigator.pushNamed(
                            context,
                            '/profile/view',
                            arguments: order.freelancerId,
                          ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ─────────────────────────────────────
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
                              // Name row — tap handled by parent InkWell (detail sheet)
                              Text(
                                widget.isFreelancerView
                                    ? 'From: $clientName'
                                    : 'To: $freelancerName',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.4)),
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

                    // ── Message ────────────────────────────────────────
                    Text(order.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 8),

                    // ── Details row ────────────────────────────────────
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

                    // ── Freelancer note (on accept/reject) ─────────────
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

                    // ── Action buttons ─────────────────────────────────
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
                            // Client view: Edit + Cancel
                            TextButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit'),
                              onPressed: _handleEdit,
                            ),
                            const SizedBox(width: 4),
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

// ── Detail bottom-sheet row ────────────────────────────────────────────────

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: valueColor)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
