import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../services/supabase_storage_service.dart';
import '../../../services/file_storage_service.dart';
import '../../../shared/widgets/camera_picker_screen.dart';
import '../../../state/app_state.dart';
import '../models/portfolio_item.dart';

/// Add or edit a single [PortfolioItem] on the freelancer's profile.
class PortfolioFormScreen extends StatefulWidget {
  const PortfolioFormScreen({super.key, this.existing});
  final PortfolioItem? existing;

  @override
  State<PortfolioFormScreen> createState() => _PortfolioFormScreenState();
}

class _PortfolioFormScreenState extends State<PortfolioFormScreen> {
  static const _uuid = Uuid();

  static const _durationUnits = ['Days', 'Weeks', 'Months'];

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagInput = TextEditingController();

  String? _imageUrl;
  bool _isLoading = false;
  final List<String> _skills = [];
  int _durationAmount = 1;
  String _durationUnit = 'Days';

  // ── Unsaved-changes detection ─────────────────────────────────────────────
  late String _origTitle;
  late String _origDesc;
  late String? _origImage;
  late List<String> _origSkills;
  late int _origDurationAmount;
  late String _origDurationUnit;

  bool get _hasChanges =>
      _titleCtrl.text.trim() != _origTitle ||
      _descCtrl.text.trim() != _origDesc ||
      _imageUrl != _origImage ||
      !_listEq(_skills, _origSkills) ||
      _durationAmount != _origDurationAmount ||
      _durationUnit != _origDurationUnit;

  static bool _listEq(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description ?? '';
      _imageUrl = e.imageUrl;
      _skills.addAll(e.skills);
      // Parse stored duration string e.g. "2 Weeks"
      final dur = e.projectDate;
      if (dur != null && dur.isNotEmpty) {
        final parts = dur.split(' ');
        if (parts.length == 2) {
          final amount = int.tryParse(parts[0]);
          final unit = parts[1];
          if (amount != null && _durationUnits.contains(unit)) {
            _durationAmount = amount.clamp(1, 7);
            _durationUnit = unit;
          }
        }
      }
    }
    _origTitle         = _titleCtrl.text.trim();
    _origDesc          = _descCtrl.text.trim();
    _origImage         = _imageUrl;
    _origSkills        = List.from(_skills);
    _origDurationAmount = _durationAmount;
    _origDurationUnit  = _durationUnit;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    String? localPath;
    if (source == ImageSource.camera) {
      localPath = await CameraPickerScreen.open(context);
    } else {
      final xfile = await ImagePicker()
          .pickImage(source: source, maxWidth: 1200, imageQuality: 85);
      if (xfile == null) return;
      localPath =
          await FileStorageService.instance.saveImage(xfile, 'portfolio');
    }
    if (localPath == null || !mounted) return;

    final userId = AppState.instance.currentUser?.uid;
    final remoteUrl = userId != null
        ? await SupabaseStorageService.instance.uploadImage(
            localPath: localPath,
            bucket: SupabaseStorageService.bucketServicePortfolio,
            userId: userId,
          )
        : null;
    setState(() => _imageUrl = remoteUrl ?? localPath);
  }

  void _showImagePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _addSkill() {
    final tag = _tagInput.text.trim();
    if (tag.isEmpty || _skills.contains(tag)) {
      _tagInput.clear();
      return;
    }
    setState(() {
      _skills.add(tag);
      _tagInput.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final me = AppState.instance.currentUser!;
    final item = PortfolioItem(
      id: _isEdit ? widget.existing!.id : _uuid.v4(),
      freelancerId: me.uid,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      imageUrl: _imageUrl,
      projectDate: '$_durationAmount $_durationUnit',
      skills: List.from(_skills),
      createdAt: _isEdit ? widget.existing!.createdAt : DateTime.now(),
    );

    final err = _isEdit
        ? await AppState.instance.updatePortfolioItem(item)
        : await AppState.instance.addPortfolioItem(item);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit
              ? 'Portfolio item updated!'
              : 'Portfolio item added!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
        title: Text(_isEdit ? 'Edit Portfolio Item' : 'Add Portfolio Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image picker ────────────────────────────────────────────
              GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: _imageUrl != null
                        ? Colors.black
                        : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  child: _imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _imageUrl!.startsWith('http')
                              ? Image.network(_imageUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const _ImagePlaceholder())
                              : Image.file(File(_imageUrl!), fit: BoxFit.contain),
                        )
                      : const _ImagePlaceholder(),
                ),
              ),
              if (_imageUrl != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Remove image',
                      style: TextStyle(color: Colors.red)),
                  onPressed: () => setState(() => _imageUrl = null),
                ),
              const SizedBox(height: 16),

              // ── Title ────────────────────────────────────────────────────
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Project Title *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. E-commerce Website Redesign',
                ),
                maxLength: 100,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),

              // ── Duration ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _durationAmount,
                      decoration: const InputDecoration(
                        labelText: 'Duration Amount',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(7, (i) => i + 1)
                          .map((v) => DropdownMenuItem(
                              value: v, child: Text('$v')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _durationAmount = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _durationUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: _durationUnits
                          .map((u) => DropdownMenuItem(
                              value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _durationUnit = v;
                            _durationAmount = 1;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Description ──────────────────────────────────────────────
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'What did you do? What was the outcome?',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 1000,
              ),
              const SizedBox(height: 12),

              // ── Skills / Tags ─────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skills Used  (${_skills.length}/10)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_skills.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _skills
                              .map((t) => Chip(
                                    label: Text(t),
                                    onDeleted: () =>
                                        setState(() => _skills.remove(t)),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tagInput,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Flutter, UI Design…',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addSkill(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.add),
                            onPressed: _addSkill,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Submit ────────────────────────────────────────────────────
              FilledButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(_isEdit ? 'Save Changes' : 'Add to Portfolio'),
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text('Tap to add project image',
            style: TextStyle(color: Colors.grey.shade500)),
      ],
    );
  }
}
