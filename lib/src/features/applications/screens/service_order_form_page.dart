import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../../services/models/freelancer_service.dart';
import '../models/service_order.dart';
import '../services/service_order_service.dart';

/// Client-facing form for submitting **or editing** a [ServiceOrder].
///
/// Pass [existing] to pre-fill the form for editing a pending order.
/// Pass [service] (without [existing]) to create a fresh order.
///
/// Fields:
///  - Message (required, 20-2000 chars) — describe what you need
///  - Proposed budget (optional, numeric)
///  - Timeline in days (optional, 1-365)
class ServiceOrderFormPage extends StatefulWidget {
  const ServiceOrderFormPage({
    super.key,
    this.service,
    this.existing,
  }) : assert(service != null || existing != null,
            'Provide either service (new) or existing (edit).');

  /// The service being ordered — required for new orders.
  final FreelancerService? service;

  /// An existing pending order — required for edits.
  final ServiceOrder? existing;

  bool get isEditing => existing != null;

  @override
  State<ServiceOrderFormPage> createState() => _ServiceOrderFormPageState();
}

class _ServiceOrderFormPageState extends State<ServiceOrderFormPage> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  late final _messageController = TextEditingController(
      text: widget.existing?.message ?? '');
  late final _budgetController = TextEditingController(
      text: widget.existing?.proposedBudget?.toStringAsFixed(0) ?? '');
  // Timeline: amount text field + unit dropdown (Days / Weeks / Months).
  late final _timelineAmountController = TextEditingController(
      text: _daysToAmount(widget.existing?.timelineDays));
  String _timelineUnit = _daysToUnit(widget.existing?.timelineDays);
  bool _isLoading = false;

  /// Converts stored days back to a display amount.
  /// e.g. 14 days → '2' (Weeks), 60 days → '2' (Months), 5 days → '5' (Days).
  static String _daysToAmount(int? days) {
    if (days == null) return '';
    if (days % 30 == 0) return (days ~/ 30).toString();
    if (days % 7 == 0) return (days ~/ 7).toString();
    return days.toString();
  }

  static String _daysToUnit(int? days) {
    if (days == null) return 'Days';
    if (days % 30 == 0) return 'Months';
    if (days % 7 == 0) return 'Weeks';
    return 'Days';
  }

  /// Converts the amount + unit selection back to total days for storage.
  int? _computeDays() {
    final raw = _timelineAmountController.text.trim();
    if (raw.isEmpty) return null;
    final n = int.tryParse(raw);
    if (n == null || n <= 0) return null;
    return switch (_timelineUnit) {
      'Weeks'  => n * 7,
      'Months' => n * 30,
      _        => n,
    };
  }

  // ── Unsaved-changes detection ─────────────────────────────────────────────
  bool get _hasChanges {
    if (widget.isEditing) {
      final orig = widget.existing!;
      return _messageController.text.trim() != orig.message.trim() ||
          _budgetController.text.trim() !=
              (orig.proposedBudget?.toStringAsFixed(0) ?? '') ||
          _timelineAmountController.text.trim() !=
              _daysToAmount(orig.timelineDays) ||
          _timelineUnit != _daysToUnit(orig.timelineDays);
    }
    return _messageController.text.trim().isNotEmpty ||
        _budgetController.text.trim().isNotEmpty ||
        _timelineAmountController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _budgetController.dispose();
    _timelineAmountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = AppState.instance.currentUser!;
    final budget = _budgetController.text.trim().isEmpty
        ? null
        : double.tryParse(_budgetController.text.trim());
    final days = _computeDays();

    String? error;

    if (widget.isEditing) {
      // Edit mode — rebuild order so optional fields can be cleared to null
      final orig = widget.existing!;
      final updated = ServiceOrder(
        id: orig.id,
        serviceId: orig.serviceId,
        serviceTitle: orig.serviceTitle,
        freelancerId: orig.freelancerId,
        freelancerName: orig.freelancerName,
        clientId: orig.clientId,
        clientName: orig.clientName,
        status: orig.status,
        freelancerNote: orig.freelancerNote,
        createdAt: orig.createdAt,
        message: _messageController.text.trim(),
        proposedBudget: budget,   // null clears the field
        timelineDays: days,       // null clears the field
        updatedAt: DateTime.now(),
      );
      error = await AppState.instance.updateServiceOrder(updated);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        Navigator.pop(context, true); // signal a successful save
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated.')),
        );
      }
    } else {
      // Create mode — build a new order
      final order = ServiceOrder(
        id: _uuid.v4(),
        serviceId: widget.service!.id,
        serviceTitle: widget.service!.title,
        freelancerId: widget.service!.freelancerId,
        freelancerName: widget.service!.freelancerName,
        clientId: user.uid,
        clientName: user.displayName,
        message: _messageController.text.trim(),
        status: ServiceOrderStatus.pending,
        proposedBudget: budget,
        timelineDays: days,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      error = await AppState.instance.submitServiceOrder(order);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Order submitted! The freelancer will respond soon.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEditing;
    final order = widget.existing;
    final svc = widget.service;

    // Service info — prefer data from the existing order when editing
    final serviceTitle = order?.serviceTitle ?? svc?.title ?? '';
    final freelancerName = order?.freelancerName ?? svc?.freelancerName ?? '';
    final priceDisplay = svc?.priceDisplay;

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
      appBar: AppBar(title: Text(isEdit ? 'Edit Order' : 'Order Service')),
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
                            Text(serviceTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text('by $freelancerName',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                            if (priceDisplay != null)
                              Text(priceDisplay,
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
                  labelText: 'Your Price (RM) — optional',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                  helperText:
                      'Leave blank to accept the service\'s listed price.',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                // Only digits and a single dot allowed
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: ServiceOrderService.validateBudget,
              ),
              const SizedBox(height: 16),

              // ── Timeline (optional) — number + unit dropdown ───────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _timelineAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Expected Timeline — optional',
                        border: OutlineInputBorder(),
                        helperText: 'Leave blank to use the listed delivery time.',
                        helperMaxLines: 2,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _timelineUnit,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                      ),
                      items: ['Days', 'Weeks', 'Months']
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _timelineUnit = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Submit / Save button ───────────────────────────────────
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEdit ? 'Save Changes' : 'Submit Order',
                        style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 8),
              Text(
                isEdit
                    ? 'Changes are only allowed while the order is pending.'
                    : 'The freelancer will review your order and accept or decline.',
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
