import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/enums/dispute_resolution.dart';
import '../../../../shared/enums/dispute_status.dart';
import '../../../../state/app_state.dart';
import '../../models/dispute_record.dart';
import '../../services/dispute_service.dart';

/// Admin screen for reviewing a dispute and selecting a resolution.
class AdminDisputeReviewScreen extends StatefulWidget {
  const AdminDisputeReviewScreen({super.key, required this.dispute});

  final DisputeRecord dispute;

  @override
  State<AdminDisputeReviewScreen> createState() =>
      _AdminDisputeReviewScreenState();
}

class _AdminDisputeReviewScreenState extends State<AdminDisputeReviewScreen> {
  late DisputeRecord _dispute;

  DisputeResolution _selectedResolution = DisputeResolution.noAction;
  final _notesCtrl = TextEditingController();
  final _refundCtrl = TextEditingController();

  bool _processing = false;
  double? _remainingHeld;
  int _milestoneCount = 0; // used to hide Partial Split for single delivery

  @override
  void initState() {
    super.initState();
    _dispute = widget.dispute;
    _loadPayment();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _refundCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPayment() async {
    final results = await Future.wait([
      AppState.instance.loadPaymentForProject(_dispute.projectId),
      AppState.instance.getMilestonesForProject(_dispute.projectId),
    ]);
    if (mounted) {
      setState(() {
        _remainingHeld = (results[0] as dynamic)?.remainingHeld as double?;
        _milestoneCount = (results[1] as List).length;
        // If admin had Partial Split selected but project is single delivery,
        // reset to a valid option.
        if (_milestoneCount <= 1 &&
            _selectedResolution == DisputeResolution.partialSplit) {
          _selectedResolution = DisputeResolution.fullRefundToClient;
        }
      });
    }
  }

  Future<void> _startReview() async {
    setState(() => _processing = true);
    final error = await AppState.instance.startDisputeReview(_dispute);
    if (!mounted) return;
    setState(() => _processing = false);
    if (error != null) {
      _showError(error);
    } else {
      setState(() {
        _dispute = AppState.instance.activeDispute ?? _dispute;
      });
    }
  }

  Future<void> _confirmResolution() async {
    // Validate partial split amount
    if (_selectedResolution == DisputeResolution.partialSplit) {
      final refAmt = double.tryParse(_refundCtrl.text) ?? 0;
      final valError = DisputeService.validatePartialSplit(
          refAmt, _remainingHeld ?? 0);
      if (valError != null) {
        _showError(valError);
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Resolution'),
        content: Text(
          'You are about to resolve this dispute as:\n\n'
          '"${_selectedResolution.displayName}"\n\n'
          'This action is irreversible. Payment adjustments will be processed immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _processing = true);

    double? clientRefund;
    if (_selectedResolution == DisputeResolution.partialSplit) {
      clientRefund = double.tryParse(_refundCtrl.text);
    }

    final error = await AppState.instance.resolveDispute(
      dispute: _dispute,
      resolution: _selectedResolution,
      adminNotes: _notesCtrl.text,
      clientRefundAmount: clientRefund,
    );

    if (!mounted) return;
    setState(() => _processing = false);

    if (error != null) {
      _showError(error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Dispute resolved successfully.'),
        backgroundColor: Colors.green.shade700,
      ));
      setState(() {
        _dispute = AppState.instance.activeDispute ?? _dispute;
      });
    }
  }

  Future<void> _closeDispute() async {
    setState(() => _processing = true);
    final error = await AppState.instance.closeDispute(_dispute);
    if (!mounted) return;
    setState(() => _processing = false);
    if (error != null) {
      _showError(error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Dispute archived.'),
      ));
      Navigator.of(context).pop();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isTerminal = _dispute.status.isTerminal;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Dispute')),
      body: _processing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Status banner ──────────────────────────────────────────
                _StatusBanner(status: _dispute.status),
                const SizedBox(height: 16),

                // ── Dispute details ────────────────────────────────────────
                _Section(
                  title: 'Dispute Details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row('Reason', _dispute.reason.displayName),
                      _Row(
                        'Raised by',
                        _dispute.isRaisedByClient ? 'Client' : 'Freelancer',
                      ),
                      _Row('Filed', _fmt(_dispute.createdAt)),
                      const Divider(height: 16),
                      Text('Description', style: tt.labelMedium),
                      const SizedBox(height: 4),
                      Text(_dispute.description, style: tt.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Evidence links ─────────────────────────────────────────
                if (_dispute.hasEvidence)
                  _Section(
                    title: 'Evidence (${_dispute.evidenceUrls.length})',
                    child: Column(
                      children: _dispute.evidenceUrls
                          .asMap()
                          .entries
                          .map((e) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 14,
                                  child: Text('${e.key + 1}',
                                      style:
                                          const TextStyle(fontSize: 12)),
                                ),
                                title: Text(
                                  e.value,
                                  style: tt.bodySmall?.copyWith(
                                      color: cs.primary,
                                      decoration: TextDecoration.underline),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _openUrl(e.value),
                              ))
                          .toList(),
                    ),
                  ),
                if (_dispute.hasEvidence) const SizedBox(height: 12),

                // ── Payment info ───────────────────────────────────────────
                if (_remainingHeld != null)
                  _Section(
                    title: 'Escrow Balance',
                    child: Column(
                      children: [
                        _Row(
                          'Remaining held',
                          'RM ${_remainingHeld!.toStringAsFixed(2)}',
                          valueStyle: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                if (_remainingHeld != null) const SizedBox(height: 12),

                // ── Resolution (if already resolved) ──────────────────────
                if (_dispute.resolution != null)
                  _Section(
                    title: 'Resolution',
                    child: Column(
                      children: [
                        _Row('Decision', _dispute.resolution!.displayName),
                        if (_dispute.clientRefundAmount != null)
                          _Row('Client refund',
                              'RM ${_dispute.clientRefundAmount!.toStringAsFixed(2)}'),
                        if (_dispute.freelancerReleaseAmount != null)
                          _Row('Freelancer release',
                              'RM ${_dispute.freelancerReleaseAmount!.toStringAsFixed(2)}'),
                        if (_dispute.adminNotes != null) ...[
                          const Divider(height: 16),
                          Text('Admin Notes', style: tt.labelMedium),
                          const SizedBox(height: 4),
                          Text(_dispute.adminNotes!, style: tt.bodyMedium),
                        ],
                      ],
                    ),
                  ),

                // ── Actions ────────────────────────────────────────────────
                if (!isTerminal) ...[
                  const SizedBox(height: 20),

                  if (_dispute.status == DisputeStatus.open)
                    OutlinedButton.icon(
                      onPressed: _startReview,
                      icon: const Icon(Icons.search),
                      label: const Text('Start Review'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),

                  if (_dispute.status == DisputeStatus.underReview) ...[
                    const SizedBox(height: 16),
                    Text('Resolution', style: tt.titleMedium),
                    const SizedBox(height: 8),

                    // Resolution picker — hide Partial Split for single delivery
                    ...DisputeResolution.values
                        .where((r) => !(r == DisputeResolution.partialSplit &&
                            _milestoneCount <= 1))
                        .map((r) => InkWell(
                          onTap: () =>
                              setState(() => _selectedResolution = r),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Radio<DisputeResolution>(
                                  value: r,
                                  groupValue: _selectedResolution,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(
                                          () => _selectedResolution = v);
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(top: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(r.displayName,
                                            style: tt.bodyMedium?.copyWith(
                                                fontWeight:
                                                    FontWeight.w500)),
                                        Text(r.description,
                                            style: tt.bodySmall?.copyWith(
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),

                    // Partial split amount field
                    if (_selectedResolution == DisputeResolution.partialSplit) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _refundCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Client refund amount (RM)',
                          helperText:
                              'Remaining held: RM ${(_remainingHeld ?? 0).toStringAsFixed(2)}',
                          prefixText: 'RM ',
                        ),
                      ),
                      if (_refundCtrl.text.isNotEmpty &&
                          _remainingHeld != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _PaymentPreviewCard(
                            clientRefund:
                                double.tryParse(_refundCtrl.text) ?? 0,
                            remainingHeld: _remainingHeld!,
                          ),
                        ),
                    ],

                    const SizedBox(height: 16),

                    // Admin notes
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Admin notes (internal, not shown to parties)',
                      ),
                    ),
                    const SizedBox(height: 16),

                    FilledButton.icon(
                      onPressed: _confirmResolution,
                      icon: const Icon(Icons.gavel),
                      label: const Text('Confirm Resolution'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ],

                // ── Close (archive) once resolved ──────────────────────────
                if (_dispute.status == DisputeStatus.resolved) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _closeDispute,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive Dispute'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Future<void> _openUrl(String url) async {
    // Copy the link to clipboard so the admin can paste it in a browser.
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child:
                Text(label, style: tt.labelMedium?.copyWith(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: valueStyle ?? tt.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final DisputeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DisputeStatus.open        => Colors.orange,
      DisputeStatus.underReview => Colors.blue,
      DisputeStatus.resolved    => Colors.green,
      DisputeStatus.closed      => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.gavel, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            status.displayName,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PaymentPreviewCard extends StatelessWidget {
  const _PaymentPreviewCard({
    required this.clientRefund,
    required this.remainingHeld,
  });

  final double clientRefund;
  final double remainingHeld;

  @override
  Widget build(BuildContext context) {
    final freelancerGross = (remainingHeld - clientRefund).clamp(0.0, remainingHeld);
    final platformFee = freelancerGross * 0.10;
    final freelancerNet = freelancerGross - platformFee;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Preview',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.indigo.shade700)),
          const SizedBox(height: 8),
          _PreviewRow('Client refund',
              'RM ${clientRefund.toStringAsFixed(2)}', Colors.teal),
          _PreviewRow('Freelancer gross',
              'RM ${freelancerGross.toStringAsFixed(2)}', Colors.indigo),
          _PreviewRow('Platform fee (10%)',
              '− RM ${platformFee.toStringAsFixed(2)}', Colors.red),
          const Divider(height: 12),
          _PreviewRow('Freelancer net',
              'RM ${freelancerNet.toStringAsFixed(2)}', Colors.green,
              bold: true),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value, this.color, {this.bold = false});

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.w600 : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}
