import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../../services/models/freelancer_service.dart';
import '../models/service_order.dart';
import '../../transactions/screens/project_detail_page.dart';
import 'client_service_order_detail_page.dart';
import 'service_order_detail_page.dart';
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
    final order = widget.order;

    // Resolve the service from in-memory state so we can show listed
    // price / delivery days next to the client's proposed values.
    FreelancerService? svc;
    for (final s in [
      ...AppState.instance.myServices,
      ...AppState.instance.services,
    ]) {
      if (s.id == order.serviceId) {
        svc = s;
        break;
      }
    }

    // ── Price resolution (mirrors acceptServiceOrder logic) ──────────────
    final double? clientPrice  = order.proposedBudget;
    final double? listedPrice  = svc?.priceMax ?? svc?.priceMin;
    final double? effectiveBudget = clientPrice ?? listedPrice;

    // ── Timeline resolution ───────────────────────────────────────────────
    final int? clientDays     = order.timelineDays;
    final int? listedDays     = svc?.deliveryDays;
    final int? effectiveDays  = clientDays ?? listedDays;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Order'),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accept "${order.serviceTitle}" from ${order.clientName}?\n'
                'A project will be created with the details below.',
              ),
              const SizedBox(height: 14),

              // ── Price & Timeline summary card ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget row
                    _AcceptInfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Budget',
                      effectiveValue: effectiveBudget != null
                          ? 'RM ${effectiveBudget.toStringAsFixed(2)}'
                          : 'Not set',
                      sourceLabel: clientPrice != null
                          ? "Client's proposed price"
                          : listedPrice != null
                              ? 'Your listed price'
                              : null,
                      isClientOverride: clientPrice != null,
                      secondaryNote: clientPrice != null && listedPrice != null
                          ? 'Your listed price: RM ${listedPrice.toStringAsFixed(2)}'
                          : null,
                    ),

                    const SizedBox(height: 12),

                    // Timeline row
                    _AcceptInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Deadline',
                      effectiveValue: effectiveDays != null
                          ? _formatDays(effectiveDays)
                          : 'Not set',
                      sourceLabel: clientDays != null
                          ? "Client's requested timeline"
                          : listedDays != null
                              ? 'Your listed delivery time'
                              : null,
                      isClientOverride: clientDays != null,
                      secondaryNote:
                          clientDays != null && listedDays != null
                              ? 'Your listed delivery: ${_formatDays(listedDays)}'
                              : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note to client (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Looking forward to working with you!',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              final err = await AppState.instance
                  .acceptServiceOrder(widget.order, noteCtrl.text);
              if (!mounted) return;
              setState(() => _loading = false);
              if (err != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
                return;
              }
              // Navigate to the newly created project.
              final project = AppState.instance.projects.firstWhere(
                (p) => p.serviceOrderId == widget.order.id,
                orElse: () => AppState.instance.projects.first,
              );
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProjectDetailPage(projectId: project.id),
                  ),
                );
              }
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
    final cs = Theme.of(context).colorScheme;

    // Live name lookups so renames show immediately on both views.
    final clientName = AppState.instance.users
            .where((u) => u.uid == order.clientId)
            .firstOrNull
            ?.displayName ??
        order.clientName;
    final freelancerName = AppState.instance.users
            .where((u) => u.uid == order.freelancerId)
            .firstOrNull
            ?.displayName ??
        order.freelancerName;

    // "Other party" — whose card are we looking at?
    final otherName =
        widget.isFreelancerView ? clientName : freelancerName;
    final otherInitial =
        otherName.isNotEmpty ? otherName[0].toUpperCase() : '?';

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
              //  - Freelancer → ServiceOrderDetailPage (view + accept/reject)
              //  - Client     → ClientServiceOrderDetailPage (view + edit/cancel)
              onTap: widget.isFreelancerView
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ServiceOrderDetailPage(order: order),
                        ),
                      ).then((_) => AppState.instance.reloadServiceOrders())
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ClientServiceOrderDetailPage(order: order),
                        ),
                      ).then((_) => AppState.instance.reloadServiceOrders()),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: avatar + name + service title + status ──
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          child: Text(otherInitial),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(otherName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              Text(order.serviceTitle,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
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

                    // ── Info box: expected price + timeline ────────────
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _OrderInfoChip(
                              icon: Icons.payments_outlined,
                              label: 'Expected Price',
                              value: order.proposedBudget != null
                                  ? 'RM ${order.proposedBudget!.toStringAsFixed(0)}'
                                  : 'Freelancer\'s price',
                              isFallback: order.proposedBudget == null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _OrderInfoChip(
                              icon: Icons.schedule_outlined,
                              label: 'Expected Timeline',
                              value: order.timelineDisplay ?? 'Freelancer\'s delivery',
                              isFallback: order.timelineDays == null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Freelancer note (shown after accept/reject) ─────
                    if (order.freelancerNote != null &&
                        order.freelancerNote!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest
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

// ── Compact price / timeline chip inside order card ───────────────────────────

class _OrderInfoChip extends StatelessWidget {
  const _OrderInfoChip({
    required this.icon,
    required this.label,
    required this.value,
    this.isFallback = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// When true, the value is a fallback (freelancer's listed value),
  /// shown in grey italic rather than bold primary colour.
  final bool isFallback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.black54),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isFallback ? FontWeight.normal : FontWeight.w600,
            fontStyle: isFallback ? FontStyle.italic : FontStyle.normal,
            color: isFallback
                ? Colors.grey.shade500
                : Theme.of(context).colorScheme.primary,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }
}

// ── Timeline formatting helper ────────────────────────────────────────────────

/// Converts stored days to the most readable unit (mirrors form entry).
/// 105 → "15 weeks", 60 → "2 months", 5 → "5 days".
String _formatDays(int d) {
  if (d % 30 == 0) {
    final m = d ~/ 30;
    return '$m month${m == 1 ? '' : 's'}';
  }
  if (d % 7 == 0) {
    final w = d ~/ 7;
    return '$w week${w == 1 ? '' : 's'}';
  }
  return '$d day${d == 1 ? '' : 's'}';
}

// ── Accept dialog — price / timeline summary row ────────────────────────────

class _AcceptInfoRow extends StatelessWidget {
  const _AcceptInfoRow({
    required this.icon,
    required this.label,
    required this.effectiveValue,
    required this.isClientOverride,
    this.sourceLabel,
    this.secondaryNote,
  });

  final IconData icon;
  final String label;

  /// The value that WILL be used when the project is created.
  final String effectiveValue;

  /// Where the value came from (e.g. "Client's proposed price").
  final String? sourceLabel;

  /// True when the client set a custom value (vs. the freelancer's listing).
  final bool isClientOverride;

  /// Optional second line — shows the freelancer's listed value for comparison.
  final String? secondaryNote;

  @override
  Widget build(BuildContext context) {
    // Orange = client overrode the listed value (needs attention).
    // Primary = using the freelancer's own listed value (normal).
    final color = isClientOverride
        ? Colors.orange.shade800
        : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row label
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 3),

        // Effective value — large & prominent
        Text(
          effectiveValue,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),

        // Source label (e.g. "↑ Client's proposed price")
        if (sourceLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            '↑ $sourceLabel',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],

        // Secondary note — shows listed value when client overrode it
        if (secondaryNote != null) ...[
          const SizedBox(height: 1),
          Text(
            secondaryNote!,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ],
    );
  }
}
