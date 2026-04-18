import 'package:flutter/material.dart';

import '../../../state/app_state.dart';
import '../../transactions/models/project_item.dart';
import '../models/payment_record.dart';
import '../models/payout_record.dart';

/// Displays the escrow payment record and full payout history for a project.
///
/// Accessible from the project detail page for both client and freelancer.
/// The client sees the escrow balance and refund details; the freelancer
/// sees their net earnings per milestone.
class PaymentStatusScreen extends StatefulWidget {
  const PaymentStatusScreen({super.key, required this.project});
  final ProjectItem project;

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  PaymentRecord? _payment;
  List<PayoutRecord> _payouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final payment = await AppState.instance.loadPaymentForProject(
        widget.project.id);
    final payouts =
        await AppState.instance.loadPayoutsForProject(widget.project.id);
    if (mounted) {
      setState(() {
        _payment = payment;
        _payouts = payouts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Status')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _payment == null
                  ? _buildNoPayment()
                  : _buildContent(_payment!),
            ),
    );
  }

  Widget _buildNoPayment() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'No payment record found.\n'
            'Complete checkout to start the project.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PaymentRecord payment) {
    final user = AppState.instance.currentUser!;
    final isClient = user.uid == payment.clientId;
    final color = payment.status.color;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Status banner ──────────────────────────────────────────────
        Card(
          color: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(payment.status.icon, color: color, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.status.displayName,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Text(
                            widget.project.jobTitle ?? 'Project',
                            style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'RM ${payment.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        const Text('total contract',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Release progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: payment.releaseProgress,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation(Colors.green),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(payment.releaseProgress * 100).toStringAsFixed(0)}% released',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Amounts breakdown ──────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Escrow Breakdown',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                _AmountRow('Total contract',
                    payment.totalAmount, null),
                _AmountRow('Held in escrow',
                    payment.heldAmount, Colors.blue),
                _AmountRow('Released (gross)',
                    payment.releasedAmount, Colors.green),
                if (payment.refundedAmount > 0)
                  _AmountRow('Refunded to client',
                      payment.refundedAmount, Colors.red),
                _AmountRow('Remaining held',
                    payment.remainingHeld, Colors.orange),
                const Divider(height: 20),
                _AmountRow(
                  'Platform fees collected (10%)',
                  payment.totalPlatformFeesCollected,
                  Colors.grey,
                  small: true,
                ),
                if (!isClient)
                  _AmountRow(
                    'Your net earnings so far',
                    payment.freelancerNetReceived,
                    Colors.green,
                    bold: true,
                  ),
                if (payment.stripePaymentIntentId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Intent: ${payment.stripePaymentIntentId}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Payout history ─────────────────────────────────────────────
        if (_payouts.isNotEmpty) ...[
          const Text('Payout History',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._payouts.map(
              (p) => _PayoutCard(payout: p, isClient: isClient)),
        ] else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No payouts yet.\n'
                  'Payouts are created as milestones are approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.amount, this.color,
      {this.small = false, this.bold = false});
  final String label;
  final double amount;
  final Color? color;
  final bool small;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: small ? 12 : 13,
                color: small ? Colors.grey : Colors.black87),
          ),
          Text(
            'RM ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: small ? 12 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard(
      {required this.payout, required this.isClient});
  final PayoutRecord payout;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final statusColor = payout.status.color;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments,
                    color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Milestone Payout',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    payout.status.displayName.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                _PayoutFigure(
                    'Gross', payout.grossAmount, Colors.black87),
                const Text('−',
                    style: TextStyle(
                        color: Colors.grey, fontSize: 18)),
                _PayoutFigure(
                    'Fee (${payout.platformFeePercent.toStringAsFixed(0)}%)',
                    payout.platformFee,
                    Colors.red.shade300),
                const Text('=',
                    style: TextStyle(
                        color: Colors.grey, fontSize: 18)),
                _PayoutFigure(
                  isClient ? 'Released' : 'You received',
                  payout.netAmount,
                  Colors.green,
                ),
              ],
            ),
            if (payout.payoutToken != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.tag,
                      size: 11, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text(
                    payout.payoutToken!,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayoutFigure extends StatelessWidget {
  const _PayoutFigure(this.label, this.amount, this.color);
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'RM ${amount.toStringAsFixed(2)}',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color),
        ),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
