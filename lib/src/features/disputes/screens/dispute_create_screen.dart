import 'package:flutter/material.dart';

import '../../../shared/enums/dispute_reason.dart';
import '../../../state/app_state.dart';
import '../../transactions/models/project_item.dart';

/// Screen that allows a client or freelancer to raise a formal dispute.
///
/// Opened from [ProjectDetailPage] when the project is in a disputable state.
class DisputeCreateScreen extends StatefulWidget {
  const DisputeCreateScreen({super.key, required this.project});

  final ProjectItem project;

  @override
  State<DisputeCreateScreen> createState() => _DisputeCreateScreenState();
}

class _DisputeCreateScreenState extends State<DisputeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final List<TextEditingController> _urlCtrls = [TextEditingController()];

  DisputeReason _selectedReason = DisputeReason.other;
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    for (final c in _urlCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final urls = _urlCtrls
        .map((c) => c.text.trim())
        .where((u) => u.isNotEmpty)
        .toList();

    final error = await AppState.instance.raiseDispute(
      project: widget.project,
      reason: _selectedReason,
      description: _descCtrl.text.trim(),
      evidenceUrls: urls,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Dispute submitted. An admin will review it shortly.'),
        backgroundColor: Colors.orange,
      ));
      Navigator.of(context).pop(true); // pop with true → caller refreshes
    }
  }

  void _addUrlField() {
    setState(() => _urlCtrls.add(TextEditingController()));
  }

  void _removeUrlField(int index) {
    setState(() {
      _urlCtrls[index].dispose();
      _urlCtrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Raise a Dispute')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Info banner ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Once you file a dispute, payment releases are paused '
                      'and the project is placed on hold until an admin '
                      'reviews the case.',
                      style: tt.bodySmall
                          ?.copyWith(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Project info ────────────────────────────────────────────────
            Text('Project', style: tt.labelMedium?.copyWith(color: cs.outline)),
            const SizedBox(height: 4),
            Text(
              widget.project.jobTitle ?? widget.project.id,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Divider(height: 32),

            // ── Reason dropdown ─────────────────────────────────────────────
            Text('Reason', style: tt.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<DisputeReason>(
              value: _selectedReason,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: DisputeReason.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedReason = v);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _selectedReason.description,
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 20),

            // ── Description ─────────────────────────────────────────────────
            Text('Description', style: tt.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    'Describe the issue in detail. What happened? What outcome do you expect?',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 20) {
                  return 'Please provide at least 20 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Evidence URLs ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Evidence Links (optional)', style: tt.labelLarge),
                TextButton.icon(
                  onPressed: _addUrlField,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Paste links to screenshots, documents, or any supporting files '
              '(Google Drive, Dropbox, etc.).',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 8),
            ..._urlCtrls.asMap().entries.map((entry) {
              final i = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: 'https://...',
                          prefixIcon: const Icon(Icons.link),
                          labelText: 'Evidence ${i + 1}',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                    ),
                    if (_urlCtrls.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: cs.error,
                        onPressed: () => _removeUrlField(i),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 28),

            // ── Submit ──────────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.gavel),
              label: Text(_submitting ? 'Submitting…' : 'Submit Dispute'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
