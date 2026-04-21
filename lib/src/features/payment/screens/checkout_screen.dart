import 'package:flutter/material.dart';

import '../../../services/stripe_service.dart';
import '../../../state/app_state.dart';
import '../../transactions/models/milestone_item.dart';
import '../../transactions/models/project_item.dart';
import '../services/payment_service.dart';

/// Client-facing checkout screen.
///
/// Collects a payment card via Stripe's [CardField] widget, captures the
/// full contract value in escrow, and creates a [PaymentRecord] with status
/// [PaymentStatus.held].
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.project,
    required this.milestones,
  });

  final ProjectItem project;
  final List<MilestoneItem> milestones;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _processing = false;
  String? _errorMessage;

  List<MilestoneItem> get _sorted => (List.of(widget.milestones)
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)));

  double get _total => widget.project.totalBudget ?? 0;

  double get _totalFees => widget.milestones.isEmpty
      ? PaymentService.calculatePayout(_total).platformFee
      : PaymentService.totalPlatformFees(widget.milestones);

  double get _freelancerNet => widget.milestones.isEmpty
      ? PaymentService.calculatePayout(_total).netAmount
      : PaymentService.totalFreelancerNet(widget.milestones);

  // ── Payment flow ───────────────────────────────────────────────────────────

  Future<void> _pay() async {
    if (_total <= 0) {
      setState(() => _errorMessage =
          'Contract value is RM 0. Please ensure the project has a valid price.');
      return;
    }

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      // Opens Stripe's native Payment Sheet — user enters card details there.
      // Returns the PaymentIntent ID after successful payment.
      final paymentIntentId = await StripeService.presentPaymentSheet(
        amountMyr: _total,
        projectId: widget.project.id,
      );

      // Persist the held payment in our database
      final err = await AppState.instance.processProjectPayment(
        widget.project,
        stripePaymentIntentId: paymentIntentId,
        stripePaymentMethodId: '',
      );

      if (!mounted) return;

      if (err != null) {
        setState(() {
          _errorMessage = err;
          _processing = false;
        });
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'RM ${_total.toStringAsFixed(2)} held in escrow. '
              'Funds will be released milestone by milestone.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } on StripePaymentException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message == 'Payment was cancelled.' ? null : e.message;
          _processing = false;
        });
      }
    } catch (e) {
      print('[Checkout] Unexpected error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _processing = false;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Project + fee summary ─────────────────────────────────
            _PaymentSummaryCard(
              project: widget.project,
              total: _total,
              totalFees: _totalFees,
              freelancerNet: _freelancerNet,
            ),
            const SizedBox(height: 16),

            // ── Breakdown card ────────────────────────────────────────
            if (widget.project.isSingleDelivery || _sorted.isEmpty)
              _SingleDeliveryBreakdown(total: _total)
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Milestone Breakdown',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      ..._sorted.map((m) {
                        final calc = PaymentService.calculatePayout(
                            m.paymentAmount);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: Text(
                                  '${m.orderIndex}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${m.percentage.toStringAsFixed(0)}%  ·  '
                                      'Gross RM ${calc.grossAmount.toStringAsFixed(2)}  '
                                      '− Fee RM ${calc.platformFee.toStringAsFixed(2)}  '
                                      '= Net RM ${calc.netAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total charged now:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'RM ${_total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // ── Secure payment notice ─────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Text(
                    'Payment secured by Stripe',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // ── Error ─────────────────────────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!,
                          style:
                              const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Pay button ────────────────────────────────────────────
            FilledButton.icon(
              onPressed: (_processing || _total <= 0) ? null : _pay,
              style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16)),
              icon: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payment),
              label: Text(
                _processing
                    ? 'Processing…'
                    : _total <= 0
                        ? 'Invalid Price (RM 0)'
                        : 'Hold RM ${_total.toStringAsFixed(2)} in Escrow',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (_total <= 0) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    'Project has no price set. Contact the client.',
                    style: TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Payment is required before work begins. '
                'Funds are released per milestone after your approval.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.project,
    required this.total,
    required this.totalFees,
    required this.freelancerNet,
  });

  final ProjectItem project;
  final double total;
  final double totalFees;
  final double freelancerNet;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.jobTitle ?? 'Project Payment',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Divider(height: 18),
            _InfoRow(
                'Contract value', 'RM ${total.toStringAsFixed(2)}'),
            _InfoRow('Held in escrow now',
                'RM ${total.toStringAsFixed(2)}'),
            _InfoRow(
              'Total platform fees (10% / payout)',
              'RM ${totalFees.toStringAsFixed(2)}',
              subtle: true,
            ),
            _InfoRow(
              'Freelancer receives (total)',
              'RM ${freelancerNet.toStringAsFixed(2)}',
              subtle: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Simplified breakdown shown for Single Delivery projects (no milestone list).
class _SingleDeliveryBreakdown extends StatelessWidget {
  const _SingleDeliveryBreakdown({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    final calc = PaymentService.calculatePayout(total);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.bolt, size: 16, color: Colors.orange),
              SizedBox(width: 6),
              Text('Single Delivery',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            const Text(
              'Full payment is held in escrow now and released to the '
              'freelancer only after you approve their final submission.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            const Divider(),
            _InfoRow('Gross amount',
                'RM ${calc.grossAmount.toStringAsFixed(2)}'),
            _InfoRow('Platform fee (10%)',
                '− RM ${calc.platformFee.toStringAsFixed(2)}',
                subtle: true),
            _InfoRow('Freelancer receives',
                'RM ${calc.netAmount.toStringAsFixed(2)}',
                subtle: true),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total charged now:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'RM ${total.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.subtle = false});
  final String label;
  final String value;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: subtle ? 12 : 13,
                color: subtle ? Colors.black54 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: subtle ? 12 : 13,
              fontWeight:
                  subtle ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
