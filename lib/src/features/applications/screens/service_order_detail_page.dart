import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';
import '../../services/models/freelancer_service.dart';
import '../../services/screens/service_detail_screen.dart';
import '../../transactions/screens/project_detail_page.dart';
import '../models/service_order.dart';

/// Detail page shown when a **freelancer** taps a received service order card.
///
/// Clean 2-card layout:
///  1. Service — service title, listed price, listed delivery time.
///  2. Order Details — client info, submitted date, client's message,
///     expected price (if proposed), expected timeline (if proposed).
///  Bottom bar — Reject / Accept (pending only).
class ServiceOrderDetailPage extends StatefulWidget {
  const ServiceOrderDetailPage({
    super.key,
    required this.order,
  });

  final ServiceOrder order;

  @override
  State<ServiceOrderDetailPage> createState() =>
      _ServiceOrderDetailPageState();
}

class _ServiceOrderDetailPageState extends State<ServiceOrderDetailPage> {
  bool _acting = false;

  ServiceOrder get _order => widget.order;

  FreelancerService? get _service {
    for (final s in [
      ...AppState.instance.myServices,
      ...AppState.instance.services,
    ]) {
      if (s.id == _order.serviceId) return s;
    }
    return null;
  }

  // ── Accept ─────────────────────────────────────────────────────────────────

  Future<void> _handleAccept() async {
    final svc = _service;
    final noteCtrl = TextEditingController();

    // Price resolution
    final double? clientPrice = _order.proposedBudget;
    final double? listedPrice = svc?.priceMax ?? svc?.priceMin;
    final double? effectiveBudget = clientPrice ?? listedPrice;

    // Timeline resolution
    final int? clientDays = _order.timelineDays;
    final int? listedDays = svc?.deliveryDays;
    final int? effectiveDays = clientDays ?? listedDays;

    final confirm = await showDialog<bool>(
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
                'Accept "${_order.serviceTitle}" from ${_order.clientName}?\n'
                'A project will be created with the details below.',
              ),
              const SizedBox(height: 14),

              // ── Price & Timeline summary card ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      secondaryNote:
                          clientPrice != null && listedPrice != null
                              ? 'Your listed price: RM ${listedPrice.toStringAsFixed(2)}'
                              : null,
                    ),
                    const SizedBox(height: 12),
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept')),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _acting = true);
    final err = await AppState.instance
        .acceptServiceOrder(_order, noteCtrl.text);
    if (!mounted) return;
    setState(() => _acting = false);

    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    // Navigate to the newly created project.
    final project = AppState.instance.projects.firstWhere(
      (p) => p.serviceOrderId == _order.id,
      orElse: () => AppState.instance.projects.first,
    );
    if (mounted) {
      // Replace the detail page with the project page.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectDetailPage(projectId: project.id),
        ),
      );
    }
  }

  // ── Reject ─────────────────────────────────────────────────────────────────

  Future<void> _handleReject() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _acting = true);
    final err =
        await AppState.instance.rejectServiceOrder(_order, reasonCtrl.text);
    if (!mounted) return;
    setState(() => _acting = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Order rejected.')));
    Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPending = _order.isPending;
    final svc = _service;
    final statusColor = _order.status.color;

    final clientName = AppState.instance.users
            .where((u) => u.uid == _order.clientId)
            .firstOrNull
            ?.displayName ??
        _order.clientName;

    // ── Price / timeline resolution ─────────────────────────────────────────
    final double? clientPrice = _order.proposedBudget;
    final double? listedPrice = svc?.priceMax ?? svc?.priceMin;
    final double? effectiveBudget = clientPrice ?? listedPrice;
    final bool priceFromClient = clientPrice != null;

    final int? clientDays = _order.timelineDays;
    final int? listedDays = svc?.deliveryDays;
    final int? effectiveDays = clientDays ?? listedDays;
    final bool timelineFromClient = clientDays != null;

    final submittedStr = _order.createdAt != null
        ? DateFormat('d MMM y, h:mm a').format(_order.createdAt!)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Detail')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Card 1: Service ────────────────────────────────────────────
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardLabel(
                    icon: Icons.design_services_outlined,
                    label: 'Service',
                    color: colors.primary),
                const SizedBox(height: 8),
                Text(
                  _order.serviceTitle,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                if (listedPrice != null || listedDays != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (listedPrice != null)
                        _MetaChip(
                            icon: Icons.payments_outlined,
                            label: 'RM ${listedPrice.toStringAsFixed(0)} listed',
                            color: Colors.green.shade700),
                      if (listedDays != null)
                        _MetaChip(
                            icon: Icons.timelapse_outlined,
                            label:
                                '$listedDays day${listedDays == 1 ? '' : 's'} delivery'),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View Service Details'),
                    onPressed: svc == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceDetailScreen(
                                  service: svc,
                                  readOnly: true,
                                ),
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Card 2: Order Details ──────────────────────────────────────
          _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge + date
                Row(
                  children: [
                    _StatusBadge(
                        label: _order.status.displayName.toUpperCase(),
                        color: statusColor),
                    if (submittedStr != null) ...[
                      const Spacer(),
                      Text(submittedStr,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Client info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.secondaryContainer,
                      child: Text(
                        clientName.isNotEmpty
                            ? clientName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.onSecondaryContainer),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(clientName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text('Client',
                              style: TextStyle(
                                  fontSize: 11, color: colors.primary)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline, size: 14),
                      label: const Text('View Profile'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.userProfile,
                        arguments: _order.clientId,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // What they need
                _CardLabel(
                    icon: Icons.description_outlined,
                    label: 'What They Need'),
                const SizedBox(height: 6),
                Text(_order.message,
                    style: const TextStyle(fontSize: 14, height: 1.6)),

                // ── Expected Price ────────────────────────────────────────
                if (effectiveBudget != null) ...[
                  const SizedBox(height: 16),
                  _CardLabel(
                    icon: Icons.payments_outlined,
                    label: 'Expected Price',
                    color: priceFromClient
                        ? Colors.orange.shade800
                        : Colors.green.shade700,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'RM ${effectiveBudget.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: priceFromClient
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    priceFromClient
                        ? "↑ Client's proposed price"
                        : '↑ Your listed price',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: (priceFromClient
                              ? Colors.orange.shade800
                              : Colors.green.shade700)
                          .withValues(alpha: 0.85),
                    ),
                  ),
                  if (priceFromClient && listedPrice != null)
                    Text(
                      'Your listed price: RM ${listedPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45),
                    ),
                ],

                // ── Expected Timeline ─────────────────────────────────────
                if (effectiveDays != null) ...[
                  const SizedBox(height: 16),
                  _CardLabel(
                    icon: Icons.timelapse_outlined,
                    label: 'Expected Timeline',
                    color: timelineFromClient
                        ? Colors.orange.shade800
                        : colors.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDays(effectiveDays),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: timelineFromClient
                          ? Colors.orange.shade800
                          : colors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timelineFromClient
                        ? "↑ Client's requested timeline"
                        : '↑ Your listed delivery time',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: (timelineFromClient
                              ? Colors.orange.shade800
                              : colors.primary)
                          .withValues(alpha: 0.85),
                    ),
                  ),
                  if (timelineFromClient && listedDays != null)
                    Text(
                      'Your listed delivery: ${_formatDays(listedDays)}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45),
                    ),
                ],

                // ── Freelancer note (shown for non-pending states) ─────────
                if (_order.freelancerNote != null &&
                    _order.freelancerNote!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CardLabel(
                      icon: Icons.comment_outlined, label: 'Your Note'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Text(
                      '"${_order.freelancerNote}"',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue.shade800,
                          height: 1.4,
                          fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),

      // ── Bottom bar — Reject / Accept (pending only) ────────────────────
      bottomNavigationBar: isPending
          ? _BottomBar(
              leftButton: OutlinedButton.icon(
                icon: _acting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                onPressed: _acting ? null : _handleReject,
              ),
              rightButton: FilledButton.icon(
                icon: _acting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label: const Text('Accept Order'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _acting ? null : _handleAccept,
              ),
            )
          : null,
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

// ── Timeline formatting helper ────────────────────────────────────────────────

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

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: c,
                fontWeight:
                    color != null ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.leftButton, required this.rightButton});
  final Widget leftButton;
  final Widget rightButton;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              leftButton,
              const SizedBox(width: 12),
              Expanded(child: rightButton),
            ],
          ),
        ),
      );
}

// ── Accept dialog — price / timeline summary row ──────────────────────────────

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
  final String effectiveValue;
  final String? sourceLabel;
  final bool isClientOverride;
  final String? secondaryNote;

  @override
  Widget build(BuildContext context) {
    final color = isClientOverride
        ? Colors.orange.shade800
        : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 3),
        Text(effectiveValue,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)),
        if (sourceLabel != null) ...[
          const SizedBox(height: 2),
          Text('↑ $sourceLabel',
              style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: color.withValues(alpha: 0.85))),
        ],
        if (secondaryNote != null) ...[
          const SizedBox(height: 1),
          Text(secondaryNote!,
              style: const TextStyle(
                  fontSize: 11, color: Colors.black45)),
        ],
      ],
    );
  }
}
