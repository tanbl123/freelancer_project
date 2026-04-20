import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../services/file_storage_service.dart';
import '../../../state/app_state.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _experienceController;
  late final TextEditingController _phoneController;
  late final TextEditingController _skillInput;

  List<String> _skills = [];
  String? _photoPath;
  String? _resumePath;
  bool _isLoading = false;

  // Inline errors for freelancer-only required fields
  String? _skillsError;
  String? _resumeError;

  // ── Snapshot of original values to detect unsaved changes ─────────────────
  late String _origName;
  late String _origBio;
  late String _origExperience;
  late String _origPhone;
  late List<String> _origSkills;
  late String? _origPhoto;
  late String? _origResume;

  bool get _hasChanges =>
      _nameController.text.trim() != _origName ||
      _bioController.text.trim() != _origBio ||
      _experienceController.text.trim() != _origExperience ||
      _phoneController.text.trim() != _origPhone ||
      _photoPath != _origPhoto ||
      _resumePath != _origResume ||
      !_listEquals(_skills, _origSkills);

  static bool _listEquals(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);


  @override
  void initState() {
    super.initState();
    final user = AppState.instance.currentUser!;
    _nameController = TextEditingController(text: user.displayName);
    _bioController = TextEditingController(text: user.bio ?? '');
    _experienceController =
        TextEditingController(text: user.experience ?? '');
    _phoneController = TextEditingController(text: user.phone);
    _skillInput = TextEditingController();
    _skills = List.from(user.skills);
    _photoPath = user.photoUrl;
    _resumePath = user.resumeUrl;

    // Snapshot originals for change detection
    _origName = user.displayName ?? '';
    _origBio = user.bio ?? '';
    _origExperience = user.experience ?? '';
    _origPhone = user.phone ?? '';
    _origSkills = List.from(user.skills);
    _origPhoto = user.photoUrl;
    _origResume = user.resumeUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _phoneController.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission denied.')),
          );
        }
        return;
      }
    }
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;
    final saved =
        await FileStorageService.instance.saveImage(xfile, 'avatars');
    setState(() {
      _photoPath = saved;
    });
  }

  Future<void> _pickResume() async {
    // PDF only — universally viewable on all devices without extra apps.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final saved = await FileStorageService.instance
        .savePlatformFile(result.files.first, 'resumes');
    setState(() {
      _resumePath = saved;
      _resumeError = null;
    });
  }

  Future<void> _openResume() async {
    if (_resumePath == null) return;
    final result = await OpenFile.open(_resumePath!);
    if (result.type != ResultType.done && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Open File'),
          content: const Text(
            'No PDF viewer found on this device.\n\n'
            'Please install one of these free apps:\n'
            '• Google Drive\n'
            '• Adobe Acrobat Reader\n'
            '• WPS Office',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _addSkill() {
    final s = _skillInput.text.trim();
    if (s.isEmpty) return;
    setState(() {
      if (!_skills.contains(s)) _skills.add(s);
      _skillInput.clear();
      _skillsError = null;
    });
  }

  /// Validates a Malaysian phone number.
  ///
  /// Accepts:
  ///  - Mobile   : 01X-XXXXXXX(X)  → 10–11 digits  (e.g. 0123456789, 0111234567)
  ///  - Landline : 0X-XXXXXXX(X)   → 9–10 digits   (e.g. 0312345678)
  ///  - International prefix +60 or 60 is normalised to a leading 0 before
  ///    the check, so +60123456789 is also accepted.
  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required.';

    // Strip whitespace / formatting characters
    var digits = v.trim().replaceAll(RegExp(r'[\s\-()]'), '');

    // Normalise international prefix → local format
    if (digits.startsWith('+60')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('60') && digits.length >= 10) {
      digits = '0${digits.substring(2)}';
    }

    // Malaysian mobile: 010–019, total 10–11 digits
    final isMobile = RegExp(r'^01[0-9]\d{7,8}$').hasMatch(digits);
    // Malaysian landline: 02–09, total 9–10 digits
    final isLandline = RegExp(r'^0[2-9]\d{6,8}$').hasMatch(digits);

    if (!isMobile && !isLandline) {
      return 'Enter a valid Malaysian phone number\n'
          'Mobile: 01X-XXXXXXX(X) · Landline: 0X-XXXXXXXX';
    }
    return null;
  }

  Future<void> _save() async {
    final user = AppState.instance.currentUser!;
    final isFreelancer = user.role == UserRole.freelancer;

    final formValid = _formKey.currentState!.validate();

    if (isFreelancer) {
      setState(() {
        _skillsError = _skills.isEmpty ? 'Please add at least one skill.' : null;
        _resumeError = _resumePath == null ? 'Please upload your resume (PDF).' : null;
      });
    }

    if (!formValid || _skillsError != null || _resumeError != null) return;
    setState(() => _isLoading = true);

    final bio = _bioController.text.trim();
    final experience = _experienceController.text.trim();
    final updated = user.copyWith(
      displayName: _nameController.text.trim(),
      bio: bio.isEmpty ? null : bio,
      clearBio: bio.isEmpty,
      experience: experience.isEmpty ? null : experience,
      clearExperience: experience.isEmpty,
      phone: _phoneController.text.trim(),
      skills: _skills,
      photoUrl: _photoPath,
      clearPhotoUrl: _photoPath == null,
      resumeUrl: _resumePath,
      clearResumeUrl: _resumePath == null,
    );
    await AppState.instance.updateProfile(updated);

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser!;
    final isFreelancer = user.role == UserRole.freelancer;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_hasChanges) {
          Navigator.pop(context);
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
              "You've made changes that haven't been saved yet. "
              'If you leave now, your updates will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep Editing'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard & Leave'),
              ),
            ],
          ),
        );
        if ((leave ?? false) && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile photo
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: _photoPath != null &&
                              File(_photoPath!).existsSync()
                          ? FileImage(File(_photoPath!))
                          : null,
                      child: _photoPath == null ||
                              !File(_photoPath!).existsSync()
                          ? Text(
                              user.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: PopupMenuButton<ImageSource>(
                        icon: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: ImageSource.camera,
                            child: ListTile(
                              leading: Icon(Icons.camera_alt),
                              title: Text('Camera'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: ImageSource.gallery,
                            child: ListTile(
                              leading: Icon(Icons.photo_library),
                              title: Text('Gallery'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        onSelected: _pickPhoto,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 50,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r"[\p{L}\s'\-]", unicode: true)),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  if (v.trim().length < 2) return 'Name must be at least 2 characters';
                  if (v.trim().length > 50) return 'Name must be 50 characters or fewer';
                  if (!RegExp(r"^[\p{L}\s'-]+$", unicode: true)
                      .hasMatch(v.trim())) {
                    return 'Name can only contain letters, spaces, hyphens or apostrophes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: 'e.g. 0123456789 or +60123456789',
                  helperText: 'Malaysian mobile (01X) or landline (03–09)',
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                ],
                validator: _validatePhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  hintText: 'Tell clients about yourself...',
                ),
                maxLines: 3,
              ),
              if (isFreelancer) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _experienceController,
                  decoration: const InputDecoration(
                    labelText: 'Experience *',
                    border: OutlineInputBorder(),
                    hintText: 'Describe your work experience...',
                  ),
                  maxLines: 3,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Experience is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Skills
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Skills *',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (_skills.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _skills
                                .map((s) => Chip(
                                      label: Text(s),
                                      onDeleted: () => setState(
                                          () => _skills.remove(s)),
                                      visualDensity:
                                          VisualDensity.compact,
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
                        if (_skillsError != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 13,
                                  color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 4),
                              Text(
                                _skillsError!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Resume upload
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Resume / CV *',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (_resumePath != null &&
                            File(_resumePath!).existsSync()) ...[
                          // File info row — tap to preview
                          InkWell(
                            onTap: _openResume,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.description,
                                      color: Colors.blue, size: 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _resumePath!
                                              .split('/')
                                              .last
                                              .split('\\')
                                              .last,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w500),
                                        ),
                                        const SizedBox(height: 2),
                                        const Row(
                                          children: [
                                            Icon(Icons.visibility,
                                                size: 12,
                                                color: Colors.blue),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tap to preview',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Action buttons row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openResume,
                                  icon: const Icon(Icons.visibility,
                                      size: 16),
                                  label: const Text('Preview'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    side: const BorderSide(
                                        color: Colors.blue),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickResume,
                                  icon: const Icon(Icons.swap_horiz,
                                      size: 16),
                                  label: const Text('Replace'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _resumePath = null),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                tooltip: 'Remove',
                              ),
                            ],
                          ),
                        ] else
                          OutlinedButton.icon(
                            onPressed: _pickResume,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Resume (PDF only)'),
                          ),
                        if (_resumeError != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 13,
                                  color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 4),
                              Text(
                                _resumeError!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    ), // Scaffold
    ); // PopScope
  }
}
