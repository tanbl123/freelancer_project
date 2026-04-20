import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/milestone_item.dart';
import '../models/project_item.dart';
import '../services/milestone_service.dart';

/// Freelancer builds the full milestone plan before submitting to the client
/// for approval.
///
/// Milestones are managed in local state and batch-inserted once submitted.
class MilestonePlanPage extends StatefulWidget {
  const MilestonePlanPage({super.key, required this.project});
  final ProjectItem project;

  @override
  State<MilestonePlanPage> createState() => _MilestonePlanPageState();
}

class _MilestonePlanPageState extends State<MilestonePlanPage> {
  static const _uuid = Uuid();

  /// Maximum milestones allowed per plan (prevents absurd 50-milestone plans).
  static const int _maxMilestones = 10;

  final List<MilestoneItem> _milestones = [];
  bool _submitting = false;

  // ── Helpers ────────────────────────────────────────────────────────────────

  double get _totalPct =>
      _milestones.fold(0.0, (s, m) => s + m.percentage);

  bool get _canSubmit =>
      _milestones.length >= 2 && (_totalPct - 100.0).abs() < 0.01;

  bool get _atMaxMilestones => _milestones.length >= _maxMilestones;

  double _calcAmount(double pct) =>
      (widget.project.totalBudget ?? 0) * pct / 100;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Reorder ────────────────────────────────────────────────────────────────

  void _reindex() {
    setState(() {
      for (int i = 0; i < _milestones.length; i++) {
        _milestones[i] = _milestones[i].copyWith(orderIndex: i + 1);
      }
    });
  }

  // ── Deadline helpers ───────────────────────────────────────────────────────

  /// Hard upper bound — project end date if set, otherwise 2 years out.
  DateTime get _projectDeadline =>
      widget.project.endDate ?? DateTime.now().add(const Duration(days: 730));

  /// How many calendar days are left in the project from today.
  int get _totalDaysRemaining =>
      _projectDeadline.difference(DateTime.now()).inDays.clamp(0, 9999);

  /// Clamp [d] so it never exceeds [_projectDeadline].
  DateTime _clamp(DateTime d) =>
      d.isAfter(_projectDeadline) ? _projectDeadline : d;

  /// The earliest date a NEW milestone (appended after all existing ones)
  /// can have — the day after the last milestone's deadline, or today.
  DateTime get _earliestNewDeadline {
    if (_milestones.isEmpty) return DateTime.now();
    final last = _milestones
        .reduce((a, b) => a.deadline.isAfter(b.deadline) ? a : b);
    return last.deadline.add(const Duration(days: 1));
  }

  /// The earliest date for a milestone being EDITED at [editIndex].
  /// Must be after the previous milestone's deadline (if any).
  DateTime _earliestForEdit(int editIndex) {
    if (editIndex == 0) return DateTime.now();
    // Find the milestone just before this one in order
    final sorted = List<MilestoneItem>.from(_milestones)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final thisOrder = _milestones[editIndex].orderIndex;
    final prev = sorted.lastWhere(
      (m) => m.orderIndex < thisOrder,
      orElse: () => sorted.first,
    );
    if (prev.orderIndex >= thisOrder) return DateTime.now();
    return prev.deadline.add(const Duration(days: 1));
  }

  Future<void> _showMilestoneDialog(int? editIndex) async {
    final isNew = editIndex == null;
    final existing = isNew ? null : _milestones[editIndex];
    final titleC = TextEditingController(text: existing?.title ?? '');
    final descC  = TextEditingController(text: existing?.description ?? '');
    final pctC   = TextEditingController(
        text: existing != null ? existing.percentage.toStringAsFixed(0) : '');

    // ── Deadline bounds for this milestone ───────────────────────────────
    final DateTime firstDate =
        isNew ? _earliestNewDeadline : _earliestForEdit(editIndex!);
    final DateTime lastDate = _projectDeadline;

    // Default deadline: midpoint between firstDate and lastDate, clamped.
    DateTime deadline = _clamp(
      existing?.deadline ??
          firstDate.add(
            Duration(
              days: ((lastDate.difference(firstDate).inDays) / 2)
                  .floor()
                  .clamp(0, 14),
            ),
          ),
    );
    // If editing and existing deadline is before firstDate, push it forward.
    if (deadline.isBefore(firstDate)) deadline = firstDate;

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final previewAmt =
              _calcAmount(double.tryParse(pctC.text) ?? 0);
          return AlertDialog(
            title:
                Text(editIndex != null ? 'Edit Milestone' : 'Add Milestone'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: titleC,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descC,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                        hintText: 'Describe what will be delivered…',
                      ),
                      maxLines: 3,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: pctC,
                      decoration: InputDecoration(
                        labelText: 'Percentage (%) *',
                        border: const OutlineInputBorder(),
                        suffixText: '%',
                        helperText: widget.project.totalBudget != null
                            ? '≈ RM ${previewAmt.toStringAsFixed(2)}'
                            : null,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDlg(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0 || val > 100) {
                          return 'Enter a value between 1 and 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    // Deadline bounds info
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 13, color: Colors.orange),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Project deadline: ${_fmt(lastDate)}'
                                  ' ($_totalDaysRemaining days remaining)',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                          if (!isNew) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.arrow_forward,
                                    size: 13, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  'Earliest allowed: ${_fmt(firstDate)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.blue),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: deadline,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        );
                        if (picked != null) setDlg(() => deadline = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Deadline: ${_fmt(deadline)}'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final pct = double.parse(pctC.text.trim());
                  final item = MilestoneItem(
                    id: existing?.id ?? _uuid.v4(),
                    projectId: widget.project.id,
                    title: titleC.text.trim(),
                    description: descC.text.trim(),
                    deadline: deadline,
                    paymentAmount: _calcAmount(pct),
                    percentage: pct,
                    orderIndex: editIndex != null
                        ? _milestones[editIndex].orderIndex
                        : _milestones.length + 1,
                    status: MilestoneStatus.pendingApproval,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  setState(() {
                    if (editIndex != null) {
                      _milestones[editIndex] = item;
                    } else {
                      _milestones.add(item);
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: Text(editIndex != null ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Submit plan ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final validationError =
        MilestoneService.validatePlan(_milestones, widget.project);
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(validationError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _submitting = true);
    final err = await AppState.instance.proposeMilestonePlan(
      widget.project,
      _milestones,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan submitted! Awaiting client approval.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final budget = widget.project.totalBudget;
    final remaining = 100.0 - _totalPct;
    final Color pctColor = (_totalPct - 100.0).abs() < 0.01
        ? Colors.green
        : (_totalPct > 100 ? Colors.red : Colors.orange);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Propose Milestone Plan'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: (_canSubmit && !_submitting) ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
      floatingActionButton: _atMaxMilestones
          ? null
          : FloatingActionButton.extended(
              heroTag: 'plan_add_milestone_fab',
              onPressed: () => _showMilestoneDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Milestone'),
            ),
      body: Column(
        children: [
          // ── Summary bar ──────────────────────────────────────────────────
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (budget != null)
                      Text(
                        'Budget: RM ${budget.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    else
                      const Text('No budget set'),
                    Text(
                      '${_totalPct.toStringAsFixed(1)}% / 100%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: pctColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_totalPct / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white38,
                    valueColor: AlwaysStoppedAnimation(pctColor),
                  ),
                ),
                const SizedBox(height: 4),
                // Project deadline reminder
                if (widget.project.endDate != null)
                  Row(
                    children: [
                      const Icon(Icons.event, size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        'All milestones must be on or before '
                        '${_fmt(widget.project.endDate!)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_milestones.length}/$_maxMilestones milestones',
                      style: TextStyle(
                          fontSize: 12,
                          color: _atMaxMilestones
                              ? Colors.red
                              : null),
                    ),
                    if (remaining > 0.01)
                      Text(
                        '${remaining.toStringAsFixed(1)}% unassigned',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange),
                      )
                    else if (_totalPct > 100.01)
                      Text(
                        'Over by ${(_totalPct - 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.red),
                      )
                    else
                      const Text('Ready to submit!',
                          style: TextStyle(
                              fontSize: 12, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),

          // Hint: at max cap
          if (_atMaxMilestones)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Maximum $_maxMilestones milestones reached.',
                style:
                    const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),

          // Hint: need ≥ 2 milestones
          if (_milestones.length == 1)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'Add at least 2 milestones to submit.',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: _milestones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No milestones yet.\n'
                          'Tap "Add Milestone" to start building your plan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _milestones.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _milestones.removeAt(oldIndex);
                        _milestones.insert(newIndex, item);
                      });
                      _reindex();
                    },
                    itemBuilder: (ctx, i) {
                      final m = _milestones[i];
                      final amt = _calcAmount(m.percentage);
                      return Card(
                        key: ValueKey(m.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(ctx)
                                .colorScheme
                                .primaryContainer,
                            child: Text(
                              '${m.orderIndex}',
                              style: TextStyle(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(m.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(m.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      const TextStyle(fontSize: 12)),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Text(
                                    '${m.percentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  if (budget != null)
                                    Text(
                                      'RM ${amt.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 12),
                                    ),
                                  Text(
                                    _fmt(m.deadline),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Edit',
                                onPressed: () =>
                                    _showMilestoneDialog(i),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red),
                                tooltip: 'Remove',
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Remove Milestone?'),
                                      content: Text(
                                        'Remove "${_milestones[i].title}"? '
                                        'This cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    setState(() => _milestones.removeAt(i));
                                    _reindex();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
