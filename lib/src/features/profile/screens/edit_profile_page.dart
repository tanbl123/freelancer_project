import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
    setState(() => _photoPath = saved);
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final saved = await FileStorageService.instance
        .savePlatformFile(result.files.first, 'resumes');
    setState(() => _resumePath = saved);
  }

  void _addSkill() {
    final s = _skillInput.text.trim();
    if (s.isEmpty) return;
    setState(() {
      if (!_skills.contains(s)) _skills.add(s);
      _skillInput.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = AppState.instance.currentUser!;
    final updated = user.copyWith(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
      experience: _experienceController.text.trim().isEmpty
          ? null
          : _experienceController.text.trim(),
      phone: _phoneController.text.trim(),
      skills: _skills,
      photoUrl: _photoPath,
      resumeUrl: _resumePath,
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
    final isFreelancer = user.role == 'freelancer';

    return Scaffold(
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
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r"^[\p{L}\s'-]+$", unicode: true)),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  if (v.trim().length < 2) return 'Name must be at least 2 characters';
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
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: 'e.g. 0123456789',
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  final digits =
                      v.trim().replaceAll(RegExp(r'[\s\-()]'), '');
                  if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(digits)) {
                    return 'Enter a valid phone number (e.g. 0123456789)';
                  }
                  //0123456789, 012-345-6789, +60123456789
                  return null;
                },
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
                    labelText: 'Experience',
                    border: OutlineInputBorder(),
                    hintText: 'Describe your work experience...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Skills
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Skills',
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
                        const Text('Resume / CV',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (_resumePath != null &&
                            File(_resumePath!).existsSync())
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description,
                                color: Colors.blue),
                            title: Text(
                              _resumePath!.split('/').last,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: const Text('Tap to replace'),
                            onTap: _pickResume,
                            trailing: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.red),
                              onPressed: () =>
                                  setState(() => _resumePath = null),
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: _pickResume,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Resume (PDF/DOCX)'),
                          ),
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
    );
  }
}
