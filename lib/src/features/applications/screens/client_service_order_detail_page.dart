import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';
import '../../services/models/freelancer_service.dart';
import '../../services/screens/service_detail_screen.dart';
import '../models/service_order.dart';
import 'service_order_form_page.dart';

/// Detail page shown when a **client** taps one of their own service order cards.
///
/// Clean 3-card layout:
///  1. Service — title, listed price/delivery chips, "View Service Details" button.
///  2. Freelancer — avatar, name, "View Profile" button.
///  3. Order Details — status badge, submitted date, order message,
///     expected price (if set), expected timeline (if set),
///     freelancer's response note (if any).
///  Bottom bar — Edit / Cancel (pending only).
class ClientServiceOrderDetailPage extends StatefulWidget {
  const ClientServiceOrderDetailPage({
    super.key,
    required this.order,
  });

  final ServiceOrder order;

  @override
  State<ClientServiceOrderDetailPage> createState() =>
      _ClientServiceOrderDetailPageState();
}

class _ClientServiceOrderDetailPageState
    extends State<ClientServiceOrderDetailPage> {
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

  // ── Edit ───────────────────────────────────────────────────────────────────

  void _handleEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceOrderFormPage(existing: _order),
      ),
    ).then((saved) {
      if (saved == true) {
        AppState.instance.reloadServiceOrders();
        Navigator.pop(context); // return to list after save
      }
    });
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
            'Are you sure you want to cancel this order?\n\n'
            'The freelancer will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _acting = true);
    final err = await AppState.instance.cancelServiceOrder(_order);
    if (!mounted) return;
    setState(() => _acting = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Order cancelled.')));
    Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPending = _order.isPending;
    final svc = _service;
    final statusColor = _order.status.color;

    final freelancerName = AppState.instance.users
            .where((u) => u.uid == _order.freelancerId)
            .firstOrNull
            ?.displayName ??
        _order.freelancerName;

    final listedPrice = svc?.priceMax ?? svc?.priceMin;
    final listedDays = svc?.deliveryDays;

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
                    label: 'Service Ordered',
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
                            label:
                                'RM ${listedPrice.toStringAsFixed(0)} listed',
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

          // ── Card 2: Freelancer ─────────────────────────────────────────
          _DetailCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.secondaryContainer,
                  child: Text(
                    freelancerName.isNotEmpty
                        ? freelancerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(freelancerName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      Text('Freelancer',
                          style: TextStyle(
                              fontSize: 12, color: colors.primary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline, size: 15),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.userProfile,
                    arguments: _order.freelancerId,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Card 3: Order Details ──────────────────────────────────────
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
                const SizedBox(height: 14),

                // Order message
                _CardLabel(
                    icon: Icons.description_outlined,
                    label: 'My Request'),
                const SizedBox(height: 6),
                Text(_order.message,
                    style: const TextStyle(fontSize: 14, height: 1.6)),

                // Expected price
                if (_order.proposedBudget != null) ...[
                  const SizedBox(height: 14),
                  _CardLabel(
                      icon: Icons.payments_outlined,
                      label: 'Expected Price'),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${_order.proposedBudget!.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.primary),
                  ),
                ],

                // Expected timeline
                if (_order.timelineDays != null) ...[
                  const SizedBox(height: 14),
                  _CardLabel(
                      icon: Icons.timelapse_outlined,
                      label: 'Expected Timeline'),
                  const SizedBox(height: 4),
                  Text(
                    _order.timelineDisplay ?? '',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.primary),
                  ),
                ],

                // Freelancer's response note
                if (_order.freelancerNote != null &&
                    _order.freelancerNote!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CardLabel(
                      icon: Icons.comment_outlined,
                      label: 'Freelancer\'s Note'),
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

      // ── Bottom bar — Edit / Cancel (pending only) ──────────────────────
      bottomNavigationBar: isPending
          ? _BottomBar(
              leftButton: OutlinedButton.icon(
                icon: _acting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                onPressed: _acting ? null : _handleCancel,
              ),
              rightButton: FilledButton.icon(
                icon: _acting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Order'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _acting ? null : _handleEdit,
              ),
            )
          : null,
    );
  }
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
