import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/milestone_item.dart';

/// Form for editing an already-persisted milestone (e.g. during inProgress).
///
/// For proposing a brand-new plan, use [MilestonePlanPage] instead — it
/// manages draft milestones in local state and submits them in batch.
class MilestoneFormPage extends StatefulWidget {
  const MilestoneFormPage({
    super.key,
    required this.projectId,
    required this.totalBudget,
    this.existing,
  });

  final String projectId;

  /// Used to calculate the payment amount preview from the percentage.
  final double totalBudget;

  /// When non-null the form is in edit mode; otherwise it creates a new milestone.
  final MilestoneItem? existing;

  @override
  State<MilestoneFormPage> createState() => _MilestoneFormPageState();
}

class _MilestoneFormPageState extends State<MilestoneFormPage> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _pctController;
  late DateTime _deadline;
  bool _isLoading = false;

  // ── Unsaved-changes detection ─────────────────────────────────────────────
  late String _origTitle;
  late String _origDesc;
  late String _origPct;
  late DateTime _origDeadline;

  bool get _hasChanges =>
      _titleController.text.trim() != _origTitle ||
      _descController.text.trim() != _origDesc ||
      _pctController.text.trim() != _origPct ||
      _deadline != _origDeadline;

  bool get _isEditing => widget.existing != null;

  double get _previewAmount {
    final pct = double.tryParse(_pctController.text) ?? 0;
    return widget.totalBudget * pct / 100;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _pctController = TextEditingController(
        text: e != null ? e.percentage.toStringAsFixed(0) : '');
    _deadline = e?.deadline ?? DateTime.now().add(const Duration(days: 14));
    _origTitle    = _titleController.text.trim();
    _origDesc     = _descController.text.trim();
    _origPct      = _pctController.text.trim();
    _origDeadline = _deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _pctController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final pct = double.parse(_pctController.text.trim());
    final amount = widget.totalBudget * pct / 100;

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        deadline: _deadline,
        percentage: pct,
        paymentAmount: amount,
      );
      await AppState.instance.updateMilestone(updated);
    } else {
      final milestone = MilestoneItem(
        id: _uuid.v4(),
        projectId: widget.projectId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        deadline: _deadline,
        paymentAmount: amount,
        percentage: pct,
        orderIndex: 1,
        status: MilestoneStatus.inProgress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AppState.instance.addMilestone(milestone);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(_isEditing ? 'Milestone updated!' : 'Milestone added!')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Milestone' : 'Add Milestone'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Milestone Title *',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  hintText: 'Describe what will be delivered…',
                ),
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Percentage
              TextFormField(
                controller: _pctController,
                decoration: InputDecoration(
                  labelText: 'Percentage (%) *',
                  border: const OutlineInputBorder(),
                  suffixText: '%',
                  helperText: widget.totalBudget > 0
                      ? '≈ RM ${_previewAmount.toStringAsFixed(2)} '
                          'of RM ${widget.totalBudget.toStringAsFixed(2)}'
                      : null,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Percentage is required';
                  }
                  final val = double.tryParse(v);
                  if (val == null || val <= 0 || val > 100) {
                    return 'Enter a value between 1 and 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Deadline
              OutlinedButton.icon(
                onPressed: _pickDeadline,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  'Deadline: '
                  '${_deadline.day.toString().padLeft(2, '0')}/'
                  '${_deadline.month.toString().padLeft(2, '0')}/'
                  '${_deadline.year}',
                ),
              ),
              const SizedBox(height: 24),

              // Submit
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        _isEditing ? 'Save Changes' : 'Add Milestone',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }
}
