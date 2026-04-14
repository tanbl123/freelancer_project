import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/milestone_item.dart';

class MilestoneFormPage extends StatefulWidget {
  const MilestoneFormPage({
    super.key,
    required this.projectId,
    this.existing,
  });

  final String projectId;
  final MilestoneItem? existing;

  @override
  State<MilestoneFormPage> createState() => _MilestoneFormPageState();
}

class _MilestoneFormPageState extends State<MilestoneFormPage> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _amountController;
  late DateTime _deadline;
  bool _isLoading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _amountController = TextEditingController(
        text: e != null ? e.paymentAmount.toStringAsFixed(0) : '');
    _deadline =
        e?.deadline ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        deadline: _deadline,
        paymentAmount: double.parse(_amountController.text),
      );
      await AppState.instance.updateMilestone(updated);
    } else {
      final milestone = MilestoneItem(
        id: _uuid.v4(),
        projectId: widget.projectId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        deadline: _deadline,
        paymentAmount: double.parse(_amountController.text),
        status: MilestoneStatus.draft,
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
          content: Text(
              _isEditing ? 'Milestone updated!' : 'Milestone added!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Milestone Title *',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Title is required'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  hintText: 'Describe what will be delivered...',
                ),
                maxLines: 4,
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Description is required'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount (RM) *',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  final val = double.tryParse(v);
                  if (val == null || val <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDeadline,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                    'Deadline: ${_deadline.toLocal().toString().split(' ').first}'),
              ),
              const SizedBox(height: 24),
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
    );
  }
}
