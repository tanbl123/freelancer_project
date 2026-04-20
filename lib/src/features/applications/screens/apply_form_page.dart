import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../../jobs/models/job_post.dart';
import '../../marketplace/models/marketplace_post.dart';
import '../models/application_item.dart';

class ApplyFormPage extends StatefulWidget {
  const ApplyFormPage({
    super.key,
    this.existing,
    this.preselectedPost,
    this.preselectedJobPost,
  });
  final ApplicationItem? existing;
  final MarketplacePost? preselectedPost;

  /// When navigating from [JobDetailScreen], pass the [JobPost] directly.
  /// Takes priority over [preselectedPost].
  final JobPost? preselectedJobPost;

  @override
  State<ApplyFormPage> createState() => _ApplyFormPageState();
}

class _ApplyFormPageState extends State<ApplyFormPage> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _proposalController = TextEditingController();

  bool _isLoading = false;
  String? _selectedJobId;

  List<JobPost> _availableJobPosts = [];

  // When a JobPost is preselected we store its details for use in _submit().
  JobPost? _preselectedJobPost;

  // ── Unsaved-changes detection ─────────────────────────────────────────────
  late String _origProposal;
  late String? _origJobId;

  bool get _hasChanges =>
      _proposalController.text.trim() != _origProposal ||
      _selectedJobId != _origJobId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    // JobPost takes priority over MarketplacePost
    _preselectedJobPost = widget.preselectedJobPost;

    _loadJobs();
    if (_isEditing) {
      final a = widget.existing!;
      _selectedJobId = a.jobId;
      _proposalController.text = a.proposalMessage;
    } else if (_preselectedJobPost != null) {
      _selectedJobId = _preselectedJobPost!.id;
    } else if (widget.preselectedPost != null) {
      _selectedJobId = widget.preselectedPost!.id;
    }
    _origProposal = _proposalController.text.trim();
    _origJobId    = _selectedJobId;
  }

  void _loadJobs() {
    setState(() {
      _availableJobPosts = AppState.instance.jobPosts
          .where((p) => p.isLive)
          .toList();
    });
  }

  @override
  void dispose() {
    _proposalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a job.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final user = AppState.instance.currentUser!;

    // Resolve clientId: prefer JobPost (new module), fall back to
    // MarketplacePost (legacy marketplace), then fall back to empty string.
    String resolvedClientId;
    if (_preselectedJobPost != null) {
      resolvedClientId = _preselectedJobPost!.clientId;
    } else {
      // Try to find in new job posts first
      final jobPost = AppState.instance.jobPosts
          .where((p) => p.id == _selectedJobId)
          .firstOrNull;
      if (jobPost != null) {
        resolvedClientId = jobPost.clientId;
      } else {
        final legacyPost = AppState.instance.posts
            .where((p) => p.id == _selectedJobId)
            .firstOrNull;
        resolvedClientId = legacyPost?.ownerId ?? '';
      }
    }

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        proposalMessage: _proposalController.text.trim(),
      );
      await AppState.instance.updateApplication(updated);
    } else {
      final app = ApplicationItem(
        id: _uuid.v4(),
        jobId: _selectedJobId!,
        clientId: resolvedClientId,
        freelancerId: user.uid,
        freelancerName: user.displayName,
        proposalMessage: _proposalController.text.trim(),
        expectedBudget: 0,
        timelineDays: 0,
        status: ApplicationStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final error = await AppState.instance.addApplication(app);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted!')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application updated!')),
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
          title: Text(_isEditing ? 'Edit Application' : 'Submit Application')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Job selector — hidden when a JobPost is preselected
              if (!_isEditing && _preselectedJobPost != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.work_outline, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Applying for',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text(
                              _preselectedJobPost!.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (!_isEditing)
                DropdownButtonFormField<String>(
                  value: _selectedJobId,
                  decoration: const InputDecoration(
                    labelText: 'Select Job *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: _availableJobPosts
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.title,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedJobId = v),
                  validator: (v) =>
                      v == null ? 'Please select a job' : null,
                ),
              if (!_isEditing) const SizedBox(height: 16),

              TextFormField(
                controller: _proposalController,
                decoration: const InputDecoration(
                  labelText: 'Proposal Message *',
                  border: OutlineInputBorder(),
                  hintText:
                      'Describe your approach, experience, and why you\'re the best fit...',
                ),
                maxLines: 6,
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Proposal is required'
                        : null,
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
                        _isEditing ? 'Save Changes' : 'Submit Application',
                        style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }
}
