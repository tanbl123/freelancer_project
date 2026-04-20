import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../../services/models/freelancer_service.dart';
import '../models/service_order.dart';
import '../services/service_order_service.dart';

/// Client-facing form for submitting a [ServiceOrder] against a
/// [FreelancerService].
///
/// Fields:
///  - Message (required, 20-2000 chars) — describe what you need
///  - Proposed budget (optional, numeric)
///  - Timeline in days (optional, 1-365)
class ServiceOrderFormPage extends StatefulWidget {
  const ServiceOrderFormPage({super.key, required this.service});
  final FreelancerService service;

  @override
  State<ServiceOrderFormPage> createState() => _ServiceOrderFormPageState();
}

class _ServiceOrderFormPageState extends State<ServiceOrderFormPage> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _budgetController = TextEditingController();
  final _daysController = TextEditingController();
  bool _isLoading = false;

  // ── Unsaved-changes detection (create-only form) ──────────────────────────
  bool get _hasChanges =>
      _messageController.text.trim().isNotEmpty ||
      _budgetController.text.trim().isNotEmpty ||
      _daysController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _messageController.dispose();
    _budgetController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = AppState.instance.currentUser!;
    final order = ServiceOrder(
      id: _uuid.v4(),
      serviceId: widget.service.id,
      serviceTitle: widget.service.title,
      freelancerId: widget.service.freelancerId,
      freelancerName: widget.service.freelancerName,
      clientId: user.uid,
      clientName: user.displayName,
      message: _messageController.text.trim(),
      status: ServiceOrderStatus.pending,
      proposedBudget: _budgetController.text.trim().isEmpty
          ? null
          : double.tryParse(_budgetController.text.trim()),
      timelineDays: _daysController.text.trim().isEmpty
          ? null
          : int.tryParse(_daysController.text.trim()),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final error = await AppState.instance.submitServiceOrder(order);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Order submitted! The freelancer will respond soon.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_hasChanges) { Navigator.pop(context); return; }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
                'You have unsaved changes. If you leave now, they will be lost.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Editing')),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Discard')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('Order Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Service info card ──────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.design_services_outlined,
                          color: Colors.grey, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(svc.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text('by ${svc.freelancerName}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                            if (svc.priceDisplay != null)
                              Text(svc.priceDisplay!,
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Message ────────────────────────────────────────────────
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'What do you need? *',
                  hintText:
                      'Describe your project, goals, style preferences, '
                      'references, or any special requirements...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                maxLength: 2000,
                validator: ServiceOrderService.validateMessage,
              ),
              const SizedBox(height: 16),

              // ── Proposed budget (optional) ─────────────────────────────
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Your Budget (RM) — optional',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                  helperText:
                      'Leave blank to accept the service\'s listed price.',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: ServiceOrderService.validateBudget,
              ),
              const SizedBox(height: 16),

              // ── Timeline (optional) ────────────────────────────────────
              TextFormField(
                controller: _daysController,
                decoration: const InputDecoration(
                  labelText: 'Your Expected Timeline (days) — optional',
                  border: OutlineInputBorder(),
                  suffixText: 'days',
                  helperText: 'Leave blank to use the service\'s listed '
                      'delivery time.',
                ),
                keyboardType: TextInputType.number,
                validator: ServiceOrderService.validateTimeline,
              ),
              const SizedBox(height: 28),

              // ── Submit button ──────────────────────────────────────────
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Order',
                        style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 8),
              Text(
                'The freelancer will review your order and accept or decline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }
}
