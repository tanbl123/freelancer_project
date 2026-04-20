import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../services/file_storage_service.dart';
import '../../../state/app_state.dart';
import '../models/marketplace_post.dart';

class PostFormPage extends StatefulWidget {
  const PostFormPage({super.key, this.existing});
  final MarketplacePost? existing;

  @override
  State<PostFormPage> createState() => _PostFormPageState();
}

class _PostFormPageState extends State<PostFormPage> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();
  final _skillInput = TextEditingController();

  PostType _type = PostType.jobRequest;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  final List<String> _skills = [];
  String? _imagePath;
  bool _isLoading = false;

  // ── Unsaved-changes detection ─────────────────────────────────────────────
  late String _origTitle;
  late String _origDesc;
  late String _origBudget;
  late PostType _origType;
  late DateTime _origDeadline;
  late List<String> _origSkills;
  late String? _origImage;

  bool get _hasChanges =>
      _titleController.text.trim() != _origTitle ||
      _descController.text.trim() != _origDesc ||
      _budgetController.text.trim() != _origBudget ||
      _type != _origType ||
      _deadline != _origDeadline ||
      !_listEq(_skills, _origSkills) ||
      _imagePath != _origImage;

  static bool _listEq(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.existing!;
      _titleController.text = p.title;
      _descController.text = p.description;
      _budgetController.text = p.minimumBudget.toStringAsFixed(0);
      _type = p.type;
      _deadline = p.deadline;
      _skills.addAll(p.skills);
      _imagePath = p.imageUrl;
    }
    _origTitle    = _titleController.text.trim();
    _origDesc     = _descController.text.trim();
    _origBudget   = _budgetController.text.trim();
    _origType     = _type;
    _origDeadline = _deadline;
    _origSkills   = List.from(_skills);
    _origImage    = _imagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  Future<void> _captureFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied.')),
        );
      }
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras available on this device.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final xfile = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(builder: (_) => _CameraCapturePage(camera: cameras.first)),
    );
    if (xfile == null) return;
    final saved =
        await FileStorageService.instance.saveImage(xfile, 'posts');
    setState(() => _imagePath = saved);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final xfile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    final saved =
        await FileStorageService.instance.saveImage(xfile, 'posts');
    setState(() => _imagePath = saved);
  }

  void _addSkill() {
    final skill = _skillInput.text.trim();
    if (skill.isEmpty) return;
    setState(() {
      if (!_skills.contains(skill)) _skills.add(skill);
      _skillInput.clear();
    });
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

    final user = AppState.instance.currentUser!;
    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        minimumBudget: double.parse(_budgetController.text),
        deadline: _deadline,
        skills: List.from(_skills),
        type: _type,
        imageUrl: _imagePath,
      );
      await AppState.instance.updatePost(updated);
    } else {
      final post = MarketplacePost(
        id: _uuid.v4(),
        ownerId: user.uid,
        ownerName: user.displayName,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        minimumBudget: double.parse(_budgetController.text),
        deadline: _deadline,
        skills: List.from(_skills),
        type: _type,
        imageUrl: _imagePath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AppState.instance.addPost(post);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              _isEditing ? 'Post updated!' : 'Post created successfully!')),
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
        title: Text(_isEditing ? 'Edit Listing' : 'Create Listing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Post type
              SegmentedButton<PostType>(
                segments: const [
                  ButtonSegment(
                    value: PostType.jobRequest,
                    label: Text('Job Request'),
                    icon: Icon(Icons.work_outline),
                  ),
                  ButtonSegment(
                    value: PostType.serviceOffering,
                    label: Text('Service Offering'),
                    icon: Icon(Icons.design_services),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),

              // Image section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Listing Image',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (_imagePath != null &&
                          FileStorageService.instance.fileExists(_imagePath))
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_imagePath!),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                  padding: EdgeInsets.zero,
                                  onPressed: () =>
                                      setState(() => _imagePath = null),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined,
                                    size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('No image selected',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _captureFromCamera,
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFromGallery,
                              icon:
                                  const Icon(Icons.photo_library, size: 18),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Budget (RM) *',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Budget is required';
                  final val = double.tryParse(v);
                  if (val == null || val <= 0) return 'Budget must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Deadline picker
              OutlinedButton.icon(
                onPressed: _pickDeadline,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                    'Deadline: ${_deadline.toLocal().toString().split(' ').first}'),
              ),
              const SizedBox(height: 12),

              // Skills input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Required Skills',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (_skills.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _skills
                              .map((s) => Chip(
                                    label: Text(s),
                                    onDeleted: () =>
                                        setState(() => _skills.remove(s)),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _skillInput,
                              decoration: const InputDecoration(
                                hintText: 'Add a skill',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _addSkill(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                              onPressed: _addSkill,
                              icon: const Icon(Icons.add)),
                        ],
                      ),
                    ],
                  ),
                ),
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
                    : Text(_isEditing ? 'Save Changes' : 'Publish Listing',
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

// ── In-app camera capture screen ──────────────────────────────────────────────

class _CameraCapturePage extends StatefulWidget {
  const _CameraCapturePage({required this.camera});
  final CameraDescription camera;

  @override
  State<_CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<_CameraCapturePage> {
  late CameraController _controller;
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    try {
      await _initFuture;
      final xfile = await _controller.takePicture();
      if (mounted) Navigator.pop(context, xfile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Take Photo'),
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              Center(child: CameraPreview(_controller)),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade400, width: 4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
