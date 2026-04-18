import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../services/file_storage_service.dart';
import '../../../services/supabase_storage_service.dart';
import '../../../shared/enums/job_status.dart';
import '../../../shared/widgets/camera_picker_screen.dart';
import '../../../state/app_state.dart';
import '../models/job_post.dart';
import '../services/job_post_service.dart';

/// Create-or-edit form for a [JobPost].
///
/// Pass [existing] to enter edit mode; leave null to create a new post.
/// Clients only — enforced at the UI layer (router-level guard is in
/// [AccessGuard]; further enforcement happens inside [JobPostService]).
class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key, this.existing});

  /// Non-null when editing an existing post.
  final JobPost? existing;

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _skillInput = TextEditingController();

  String _category = 'other';
  DateTime? _deadline;
  bool _allowChat = true;
  bool _isLoading = false;
  String? _coverImagePath;
  final List<String> _skills = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _titleController.text = p.title;
      _descController.text = p.description;
      _category = p.category;
      _deadline = p.deadline;
      _allowChat = p.allowPreEngagementChat;
      _coverImagePath = p.coverImageUrl;
      _skills.addAll(p.requiredSkills);
      if (p.budgetMin != null) {
        _budgetMinController.text = p.budgetMin!.toStringAsFixed(0);
      }
      if (p.budgetMax != null) {
        _budgetMaxController.text = p.budgetMax!.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    String? localPath;

    if (source == ImageSource.camera) {
      // Use the full in-app camera with live preview + retake flow.
      localPath = await CameraPickerScreen.open(context);
    } else {
      // Gallery pick — save locally first.
      final xfile = await ImagePicker()
          .pickImage(source: source, maxWidth: 1200, imageQuality: 80);
      if (xfile == null) return;
      localPath =
          await FileStorageService.instance.saveImage(xfile, 'job_covers');
    }

    if (localPath == null || !mounted) return;

    // Upload to Supabase Storage, fall back to local path on failure.
    final userId = AppState.instance.currentUser?.uid;
    final remoteUrl = userId != null
        ? await SupabaseStorageService.instance.uploadImage(
            localPath: localPath,
            bucket: SupabaseStorageService.bucketJobCovers,
            userId: userId,
          )
        : null;

    setState(() => _coverImagePath = remoteUrl ?? localPath);
  }

  // ── Skills ────────────────────────────────────────────────────────────────

  void _addSkill() {
    final s = _skillInput.text.trim();
    if (s.isEmpty) return;
    if (_skills.contains(s)) {
      _skillInput.clear();
      return;
    }
    if (_skills.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 20 skills allowed.')));
      return;
    }
    setState(() {
      _skills.add(s);
      _skillInput.clear();
    });
  }

  // ── Deadline picker ───────────────────────────────────────────────────────

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 14)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Set application deadline',
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Extra skills validation
    final skillsErr = JobPostService.validateSkills(_skills);
    if (skillsErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(skillsErr)));
      return;
    }

    // Budget cross-validation
    final min = double.tryParse(_budgetMinController.text.trim());
    final max = double.tryParse(_budgetMaxController.text.trim());
    final budgetErr = JobPostService.validateBudget(min, max);
    if (budgetErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(budgetErr)));
      return;
    }

    final user = AppState.instance.currentUser!;
    final now = DateTime.now();
    final post = JobPost(
      id: _isEdit ? widget.existing!.id : _uuid.v4(),
      clientId: user.uid,
      clientName: user.displayName,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category,
      status: _isEdit ? widget.existing!.status : JobStatus.open,
      requiredSkills: List.from(_skills),
      budgetMin: min,
      budgetMax: max,
      deadline: _deadline,
      coverImageUrl: _coverImagePath,
      allowPreEngagementChat: _allowChat,
      viewCount: _isEdit ? widget.existing!.viewCount : 0,
      applicationCount:
          _isEdit ? widget.existing!.applicationCount : 0,
      createdAt: _isEdit ? widget.existing!.createdAt : now,
      updatedAt: now,
    );

    setState(() => _isLoading = true);
    final error = _isEdit
        ? await AppState.instance.editJobPost(post)
        : await AppState.instance.createJobPost(post);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              _isEdit ? 'Job post updated!' : 'Job posted successfully!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Job Post' : 'Post a Job'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cover image ───────────────────────────────────────────
              _CoverImagePicker(
                imagePath: _coverImagePath,
                onPick: _pickImage,
                onRemove: () => setState(() => _coverImagePath = null),
              ),
              const SizedBox(height: 20),

              // ── Title ─────────────────────────────────────────────────
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title *',
                  hintText: 'e.g. Flutter Developer for E-commerce App',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 100,
                textInputAction: TextInputAction.next,
                validator: JobPostService.validateTitle,
              ),
              const SizedBox(height: 16),

              // ── Description ───────────────────────────────────────────
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText:
                      'Describe the work, scope, deliverables, and any '
                      'requirements. At least 30 characters.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                maxLength: 5000,
                textInputAction: TextInputAction.newline,
                validator: JobPostService.validateDescription,
              ),
              const SizedBox(height: 16),

              // ── Category ──────────────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: AppState.instance.categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.displayName),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 16),

              // ── Required skills ───────────────────────────────────────
              _SkillsInput(
                skills: _skills,
                controller: _skillInput,
                onAdd: _addSkill,
                onRemove: (s) => setState(() => _skills.remove(s)),
              ),
              const SizedBox(height: 16),

              // ── Budget range ──────────────────────────────────────────
              const Text('Budget (RM) — Optional',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMinController,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        border: OutlineInputBorder(),
                        prefixText: 'RM ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (v) =>
                          JobPostService.validateBudgetField(v, isMin: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('–',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMaxController,
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        border: OutlineInputBorder(),
                        prefixText: 'RM ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (v) =>
                          JobPostService.validateBudgetField(v, isMin: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Deadline ──────────────────────────────────────────────
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _deadline == null
                      ? 'Set Deadline (Optional)'
                      : 'Deadline: ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                  style: TextStyle(
                      color: _deadline != null ? colors.primary : null),
                ),
                onPressed: _pickDeadline,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              if (_deadline != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Remove deadline',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _deadline = null),
                ),
              ],
              const SizedBox(height: 16),

              // ── Pre-engagement chat toggle ─────────────────────────────
              Card(
                child: SwitchListTile(
                  value: _allowChat,
                  onChanged: (v) => setState(() => _allowChat = v),
                  title: const Text('Allow Pre-Application Chat'),
                  subtitle: const Text(
                    'Freelancers can message you before formally applying.',
                    style: TextStyle(fontSize: 12),
                  ),
                  secondary: const Icon(Icons.chat_bubble_outline),
                ),
              ),
              const SizedBox(height: 24),

              // ── Submit ────────────────────────────────────────────────
              FilledButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(
                  _isLoading
                      ? (_isEdit ? 'Saving…' : 'Posting…')
                      : (_isEdit ? 'Save Changes' : 'Post Job'),
                ),
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cover image picker ─────────────────────────────────────────────────────

class _CoverImagePicker extends StatelessWidget {
  const _CoverImagePicker({
    required this.imagePath,
    required this.onPick,
    required this.onRemove,
  });

  final String? imagePath;
  final void Function(ImageSource) onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cover Image (Optional)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (imagePath != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _isRemoteUrl(imagePath!)
                    ? Image.network(
                        imagePath!,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageFallback(),
                      )
                    : Image.file(
                        File(imagePath!),
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageFallback(),
                      ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRemove,
                ),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add Cover Image'),
            onPressed: () => _showSourceSheet(context),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        if (imagePath != null) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz, size: 14),
            label: const Text('Change image', style: TextStyle(fontSize: 12)),
            onPressed: () => _showSourceSheet(context),
          ),
        ],
      ],
    );
  }

  static bool _isRemoteUrl(String path) => path.startsWith('http');

  static Widget _imageFallback() => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined,
            color: Colors.grey, size: 40),
      );

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              subtitle: const Text('Capture a new photo'),
              onTap: () {
                Navigator.pop(ctx);
                onPick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              subtitle: const Text('Choose from your photos'),
              onTap: () {
                Navigator.pop(ctx);
                onPick(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Skills input widget ────────────────────────────────────────────────────

class _SkillsInput extends StatelessWidget {
  const _SkillsInput({
    required this.skills,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> skills;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Required Skills *',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${skills.length}/20',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (skills.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: skills
                    .map((s) => Chip(
                          label: Text(s,
                              style: const TextStyle(fontSize: 12)),
                          onDeleted: () => onRemove(s),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Flutter, UI/UX, Figma…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: onAdd,
                  tooltip: 'Add skill',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
