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
class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key, this.existing});
  final JobPost? existing;

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

// ── Timeline type ──────────────────────────────────────────────────────────
enum _TimelineType { specificDate, duration }

const _durationUnits = ['Days', 'Weeks', 'Months'];

class _JobFormScreenState extends State<JobFormScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();
  final _skillInput = TextEditingController();

  String _category = 'other';
  bool _isLoading = false;
  String? _coverImagePath;
  final List<String> _skills = [];

  // ── Timeline state ──────────────────────────────────────────────────────
  _TimelineType _timelineType = _TimelineType.specificDate;
  DateTime? _specificDate;       // used when timelineType == specificDate
  int _durationValue = 2;        // used when timelineType == duration
  String _durationUnit = 'Weeks';
  DateTime? _postingDeadline;    // posting close date, used when timelineType == duration

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _titleController.text = p.title;
      _descController.text = p.description;
      _category = p.category;
      _coverImagePath = p.coverImageUrl;
      _skills.addAll(p.requiredSkills);
      // Restore budget — prefer budgetMax; fall back to budgetMin for old range posts
      final budgetValue = p.budgetMax ?? p.budgetMin;
      if (budgetValue != null) {
        _budgetController.text = budgetValue.toStringAsFixed(0);
      }
      // Restore timeline
      if (p.projectDuration != null) {
        _timelineType = _TimelineType.duration;
        final parts = p.projectDuration!.split(' ');
        if (parts.length == 2) {
          _durationUnit = _durationUnits.contains(parts[1]) ? parts[1] : 'Weeks';
          final parsed = int.tryParse(parts[0]) ?? 1;
          _durationValue = parsed.clamp(1, _maxForUnit(_durationUnit));
        }
        _postingDeadline = p.deadline;
      } else if (p.deadline != null) {
        _timelineType = _TimelineType.specificDate;
        _specificDate = p.deadline;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  // ── Image picker ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    String? localPath;
    if (source == ImageSource.camera) {
      localPath = await CameraPickerScreen.open(context);
    } else {
      final xfile = await ImagePicker()
          .pickImage(source: source, maxWidth: 1200, imageQuality: 80);
      if (xfile == null) return;
      localPath =
          await FileStorageService.instance.saveImage(xfile, 'job_covers');
    }
    if (localPath == null || !mounted) return;
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

  // ── Skills ─────────────────────────────────────────────────────────────

  void _addSkill() {
    final s = _skillInput.text.trim();
    if (s.isEmpty) return;
    if (_skills.contains(s)) { _skillInput.clear(); return; }
    if (_skills.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 20 skills allowed.')));
      return;
    }
    setState(() { _skills.add(s); _skillInput.clear(); });
  }

  // ── Date pickers ───────────────────────────────────────────────────────

  Future<void> _pickSpecificDate() async {
    final now = DateTime.now();
    // Use date-only so "tomorrow" is always the next calendar day.
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? tomorrow.add(const Duration(days: 13)),
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 729)),
      helpText: 'Project completion date',
    );
    if (picked != null) setState(() => _specificDate = picked);
  }

  Future<void> _pickPostingDeadline() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _postingDeadline ?? tomorrow.add(const Duration(days: 6)),
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 364)),
      helpText: 'Posting close date',
    );
    if (picked != null) setState(() => _postingDeadline = picked);
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Budget validation
    final max = double.tryParse(_budgetController.text.trim());
    final budgetErr = JobPostService.validateBudget(null, max);
    if (budgetErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(budgetErr)));
      return;
    }

    // Timeline validation
    DateTime? deadline;
    String? projectDuration;

    if (_timelineType == _TimelineType.specificDate) {
      if (_specificDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a completion date.')),
        );
        return;
      }
      deadline = _specificDate;
      projectDuration = null;
    } else {
      projectDuration = '$_durationValue $_durationUnit';
      if (_postingDeadline == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please set when this posting should close.')),
        );
        return;
      }
      deadline = _postingDeadline;
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
      budgetMin: null,
      budgetMax: max,
      deadline: deadline,
      projectDuration: projectDuration,
      coverImageUrl: _coverImagePath,
      allowPreEngagementChat: true,
      viewCount: _isEdit ? widget.existing!.viewCount : 0,
      applicationCount: _isEdit ? widget.existing!.applicationCount : 0,
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
              // ── Cover image ─────────────────────────────────────────
              _CoverImagePicker(
                imagePath: _coverImagePath,
                onPick: _pickImage,
                onRemove: () => setState(() => _coverImagePath = null),
              ),
              const SizedBox(height: 20),

              // ── Title ───────────────────────────────────────────────
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

              // ── Description ─────────────────────────────────────────
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText:
                      'Describe the work, scope, deliverables, required skills '
                      'and any specific requirements. At least 30 characters.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                maxLength: 5000,
                textInputAction: TextInputAction.newline,
                validator: JobPostService.validateDescription,
              ),
              const SizedBox(height: 16),

              // ── Category ────────────────────────────────────────────
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

              // ── Skills (optional) ───────────────────────────────────
              _SkillsInput(
                skills: _skills,
                controller: _skillInput,
                onAdd: _addSkill,
                onRemove: (s) => setState(() => _skills.remove(s)),
              ),
              const SizedBox(height: 16),

              // ── Budget (required) ───────────────────────────────────
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Budget (RM) *',
                  hintText: 'e.g. 500',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a budget.';
                  }
                  final amount = double.tryParse(v.trim());
                  if (amount == null) return 'Enter a valid number.';
                  if (amount <= 0) return 'Budget must be greater than zero.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Project Timeline (required) ──────────────────────────
              _TimelineSection(
                type: _timelineType,
                specificDate: _specificDate,
                durationValue: _durationValue,
                durationUnit: _durationUnit,
                postingDeadline: _postingDeadline,
                onTypeChanged: (t) => setState(() => _timelineType = t),
                onPickSpecificDate: _pickSpecificDate,
                onDurationValueChanged: (v) =>
                    setState(() => _durationValue = v),
                onDurationUnitChanged: (u) =>
                    setState(() { _durationUnit = u; _durationValue = 1; }),
                onPickPostingDeadline: _pickPostingDeadline,
                onClearPostingDeadline: () =>
                    setState(() => _postingDeadline = null),
                fmtDate: _fmtDate,
              ),
              const SizedBox(height: 20),

              // ── Submit ───────────────────────────────────────────────
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

// ── Timeline helpers ───────────────────────────────────────────────────────

/// Maximum selectable value for a given duration unit.
int _maxForUnit(String unit) => 7;

// ── Timeline section widget ────────────────────────────────────────────────

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.type,
    required this.specificDate,
    required this.durationValue,
    required this.durationUnit,
    required this.postingDeadline,
    required this.onTypeChanged,
    required this.onPickSpecificDate,
    required this.onDurationValueChanged,
    required this.onDurationUnitChanged,
    required this.onPickPostingDeadline,
    required this.onClearPostingDeadline,
    required this.fmtDate,
  });

  final _TimelineType type;
  final DateTime? specificDate;
  final int durationValue;
  final String durationUnit;
  final DateTime? postingDeadline;
  final ValueChanged<_TimelineType> onTypeChanged;
  final VoidCallback onPickSpecificDate;
  final ValueChanged<int> onDurationValueChanged;
  final ValueChanged<String> onDurationUnitChanged;
  final VoidCallback onPickPostingDeadline;
  final VoidCallback onClearPostingDeadline;
  final String Function(DateTime) fmtDate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Guard: clamp durationValue into [1, max] in case an old saved post
    // had a value larger than the current limit (e.g. "52 Weeks").
    final maxItems = _maxForUnit(durationUnit);
    final safeValue = durationValue.clamp(1, maxItems);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: 18, color: colors.primary),
                const SizedBox(width: 8),
                const Text('Project Timeline *',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'How long will this project take to complete?',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // ── Option A: Specific date ──────────────────────────────
            RadioListTile<_TimelineType>(
              value: _TimelineType.specificDate,
              groupValue: type,
              onChanged: (v) => onTypeChanged(v!),
              contentPadding: EdgeInsets.zero,
              title: const Text('Complete by a specific date',
                  style: TextStyle(fontSize: 14)),
              dense: true,
            ),

            if (type == _TimelineType.specificDate) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined,
                          size: 16),
                      label: Text(
                        specificDate == null
                            ? 'Select date'
                            : fmtDate(specificDate!),
                        style: TextStyle(
                            color: specificDate != null
                                ? colors.primary
                                : null),
                      ),
                      onPressed: onPickSpecificDate,
                    ),
                    if (specificDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 13,
                                color: colors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Posting auto-closes on this date.',
                              style: TextStyle(
                                  fontSize: 11, color: colors.primary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // ── Option B: Duration ───────────────────────────────────
            RadioListTile<_TimelineType>(
              value: _TimelineType.duration,
              groupValue: type,
              onChanged: (v) => onTypeChanged(v!),
              contentPadding: EdgeInsets.zero,
              title: const Text('Set a duration',
                  style: TextStyle(fontSize: 14)),
              dense: true,
            ),

            if (type == _TimelineType.duration) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duration number + unit picker
                    Row(
                      children: [
                        // Number dropdown — range depends on selected unit
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: safeValue,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: List.generate(
                              maxItems,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}'),
                              ),
                            ),
                            onChanged: (v) {
                              if (v != null) onDurationValueChanged(v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Unit dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: durationUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _durationUnits
                                .map((u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    ))
                                .toList(),
                            onChanged: (u) {
                              if (u != null) onDurationUnitChanged(u);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Posting close date (required when using duration)
                    const Text(
                      'When should this posting close? *',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Set the date to stop accepting applications.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.event_outlined, size: 16),
                          label: Text(
                            postingDeadline == null
                                ? 'Select close date'
                                : fmtDate(postingDeadline!),
                            style: TextStyle(
                                color: postingDeadline != null
                                    ? colors.primary
                                    : null),
                          ),
                          onPressed: onPickPostingDeadline,
                        ),
                        if (postingDeadline != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: onClearPostingDeadline,
                            tooltip: 'Clear',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ],
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
            label:
                const Text('Change image', style: TextStyle(fontSize: 12)),
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
                const Text('Skills (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${skills.length}/20',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Add relevant skills if known — leave empty if unsure.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
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
