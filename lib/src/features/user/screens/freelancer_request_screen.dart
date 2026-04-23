import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/file_storage_service.dart';
import '../../../shared/enums/request_status.dart';
import '../../../state/app_state.dart';
import '../../user/models/certification_item.dart';
import '../../user/models/education_item.dart';
import '../../user/models/skill_with_level.dart';
import '../../user/models/work_experience.dart';

/// Allows an active Client to submit a request to become a Freelancer.
/// Also shows the status of a previously submitted request.
class FreelancerRequestScreen extends StatefulWidget {
  const FreelancerRequestScreen({super.key});

  @override
  State<FreelancerRequestScreen> createState() =>
      _FreelancerRequestScreenState();
}

class _FreelancerRequestScreenState extends State<FreelancerRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aboutController = TextEditingController();
  final _portfolioDescController = TextEditingController();
  final _motivationController = TextEditingController();

  List<SkillWithLevel> _skills = [];
  List<WorkExperience> _workExperiences = [];
  List<EducationItem> _educations = [];
  List<CertificationItem> _certifications = [];

  String? _resumePath;
  bool _isUploadingResume = false;

  bool _isLoading = false;
  String? _errorMessage;

  // ── Unsaved-changes detection ─────────────────────────────────────────────
  bool get _hasChanges =>
      _aboutController.text.trim().isNotEmpty ||
      _portfolioDescController.text.trim().isNotEmpty ||
      _motivationController.text.trim().isNotEmpty ||
      _skills.isNotEmpty ||
      _workExperiences.isNotEmpty ||
      _educations.isNotEmpty ||
      _certifications.isNotEmpty ||
      _resumePath != null;

  // Per-section inline validation errors
  String? _skillsError;
  String? _workError;
  String? _eduError;
  String? _resumeError;

  // When a previous request was rejected, this flag forces the form to show
  // even though AppState.myFreelancerRequest is non-null.
  bool _forceShowForm = false;

  // Inline form toggles
  bool _showSkillForm = false;
  bool _showWorkForm = false;
  bool _showEducationForm = false;
  bool _showCertForm = false;

  // Edit-mode index trackers (null = add mode, non-null = editing that index)
  int? _editingWorkIndex;
  int? _editingEduIndex;
  int? _editingCertIndex;

  // ── Skill inline form state ────────────────────────────────────────────────
  final _skillNameController = TextEditingController();
  String _skillLevel = 'Beginner';
  String? _skillNameError;

  // ── Work Experience inline form state ─────────────────────────────────────
  final _workTitleController = TextEditingController();
  final _workCompanyController = TextEditingController();
  final _workDescController = TextEditingController();
  final _workIndustryController = TextEditingController();
  String? _workEmploymentType;
  bool _workCurrently = false;
  DateTime? _workStartDate;
  DateTime? _workEndDate;
  String? _workTitleError;
  String? _workCompanyError;
  String? _workStartError;
  String? _workEndError;

  // ── Education inline form state ────────────────────────────────────────────
  final _eduSchoolController = TextEditingController();
  final _eduFieldController = TextEditingController();
  String _eduCountry = 'Malaysia';
  String? _eduDegree;
  int? _eduYear;
  String? _eduSchoolError;

  // ── Certification inline form state ───────────────────────────────────────
  final _certNameController = TextEditingController();
  final _certIssuedByController = TextEditingController();
  int? _certYear;
  String? _certNameError;

  @override
  void dispose() {
    _aboutController.dispose();
    _portfolioDescController.dispose();
    _motivationController.dispose();
    _skillNameController.dispose();
    _workTitleController.dispose();
    _workCompanyController.dispose();
    _workDescController.dispose();
    _workIndustryController.dispose();
    _eduSchoolController.dispose();
    _eduFieldController.dispose();
    _certNameController.dispose();
    _certIssuedByController.dispose();
    super.dispose();
  }

  void _resetSkillForm() {
    _skillNameController.clear();
    _skillLevel = 'Beginner';
    _skillNameError = null;
  }

  void _resetWorkForm() {
    _workTitleController.clear();
    _workCompanyController.clear();
    _workDescController.clear();
    _workIndustryController.clear();
    _workEmploymentType = null;
    _workCurrently = false;
    _workStartDate = null;
    _workEndDate = null;
    _workTitleError = null;
    _workCompanyError = null;
    _workStartError = null;
    _workEndError = null;
  }

  void _resetEduForm() {
    _eduSchoolController.clear();
    _eduFieldController.clear();
    _eduCountry = 'Malaysia';
    _eduDegree = null;
    _eduYear = null;
    _eduSchoolError = null;
  }

  void _resetCertForm() {
    _certNameController.clear();
    _certIssuedByController.clear();
    _certYear = null;
    _certNameError = null;
  }

  // ── Edit-mode populate helpers ────────────────────────────────────────────

  static DateTime? _parseMonthYear(String? s) {
    if (s == null) return null;
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final parts = s.split(' ');
    if (parts.length != 2) return null;
    final mi = months.indexOf(parts[0]);
    final year = int.tryParse(parts[1]);
    if (mi < 0 || year == null) return null;
    return DateTime(year, mi + 1);
  }

  void _populateWorkForm(WorkExperience w) {
    _workTitleController.text = w.title;
    _workCompanyController.text = w.company;
    _workDescController.text = w.description ?? '';
    _workIndustryController.text = w.industry ?? '';
    _workEmploymentType = w.employmentType;
    _workCurrently = w.currentlyWorkHere;
    _workStartDate = _parseMonthYear(w.startDate);
    _workEndDate = _parseMonthYear(w.endDate);
    _workTitleError = null;
    _workCompanyError = null;
    _workStartError = null;
    _workEndError = null;
  }

  void _populateEduForm(EducationItem e) {
    _eduSchoolController.text = e.school;
    _eduFieldController.text = e.fieldOfStudy ?? '';
    _eduCountry = e.country;
    _eduDegree = e.degree;
    _eduYear = e.yearOfGraduation;
    _eduSchoolError = null;
  }

  void _populateCertForm(CertificationItem c) {
    _certNameController.text = c.name;
    _certIssuedByController.text = c.issuedBy ?? '';
    _certYear = c.yearReceived;
    _certNameError = null;
  }

  // ── Shared remove confirmation ────────────────────────────────────────────
  Future<bool> _confirmRemove(String title, String itemName) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove $title?'),
            content: Text('Remove "$itemName"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Resume picker ─────────────────────────────────────────────────────────
  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _isUploadingResume = true);
    try {
      final saved = await FileStorageService.instance
          .savePlatformFile(result.files.first, 'resumes');
      setState(() {
        _resumePath = saved;
        _resumeError = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload resume: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingResume = false);
    }
  }

  // ── Month/year picker ──────────────────────────────────────────────────────
  Future<DateTime?> _pickMonthYear(DateTime? initial, {DateTime? lastDate}) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearPickerDialog(
        initialDate: initial,
        lastDate: lastDate,
      ),
    );
  }

  static String _fmtMonthYear(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${m[d.month - 1]} ${d.year}';
  }

  Future<void> _submit() async {
    // Run both validations together so ALL errors show at once
    final formValid = _formKey.currentState!.validate();

    setState(() {
      _skillsError = _skills.isEmpty ? 'Please add at least one skill.' : null;
      _workError = _workExperiences.isEmpty ? 'Please add at least one work experience.' : null;
      _eduError = _educations.isEmpty ? 'Please add at least one education entry.' : null;
      _resumeError = _resumePath == null ? 'Please upload your resume (PDF).' : null;
    });

    if (!formValid || _skillsError != null || _workError != null ||
        _eduError != null || _resumeError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = AppState.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not logged in.';
      });
      return;
    }

    // Update profile with bio, skills, experiences, education, certifications
    final updatedUser = user.copyWith(
      bio: _aboutController.text.trim(),
      skillsWithLevel: _skills,
      workExperiences: _workExperiences,
      educations: _educations,
      certifications: _certifications,
      portfolioDescription: _portfolioDescController.text.trim().isEmpty
          ? null
          : _portfolioDescController.text.trim(),
      resumeUrl: _resumePath,
    );

    try {
      await AppState.instance.updateProfile(updatedUser);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update profile: $e';
      });
      return;
    }

    final error = await AppState.instance.submitFreelancerRequest(
      _motivationController.text.trim(),
      null, // portfolioUrl — now stored as portfolioDescription in profile
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      setState(() => _forceShowForm = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request submitted! An admin will review it soon.')));
      Navigator.pop(context);
    }
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
      child: ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final existing = AppState.instance.myFreelancerRequest;

        return Scaffold(
          appBar: AppBar(title: const Text('Become a Freelancer')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: existing != null && !_forceShowForm
                  ? _buildStatusView(existing.status, existing.adminNote)
                  : _buildForm(),
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildStatusView(RequestStatus status, String? adminNote) {
    final (icon, color, title, subtitle) = switch (status) {
      RequestStatus.pending => (
          Icons.hourglass_top_rounded,
          Colors.orange,
          'Request Pending',
          'Your request is under review. We\'ll notify you once it\'s processed.',
        ),
      RequestStatus.approved => (
          Icons.check_circle_rounded,
          Colors.green,
          'Request Approved!',
          'Congratulations! You are now a Freelancer.',
        ),
      RequestStatus.rejected => (
          Icons.cancel_rounded,
          Colors.red,
          'Request Rejected',
          adminNote ?? 'Your request was not approved at this time.',
        ),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 12),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.5)),
          if (status == RequestStatus.rejected) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Submit a New Request'),
              onPressed: () => setState(() => _forceShowForm = true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Info banner ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Once approved, you will be able to offer services '
                    'and apply for jobs on the platform.',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── About section ──────────────────────────────────────────────────
          _buildSectionCard(
            title: 'About You',
            subtitle: 'Share your expertise and what you offer to clients.',
            child: TextFormField(
              controller: _aboutController,
              minLines: 5,
              maxLines: 10,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText:
                    'Share your expertise and what you offer to clients (minimum 150 characters)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 150) {
                  return 'Please provide at least 150 characters';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── Skills & Expertise section ─────────────────────────────────────
          _buildSkillsSection(),
          const SizedBox(height: 12),

          // ── Work Experience section ────────────────────────────────────────
          _buildWorkExperienceSection(),
          const SizedBox(height: 12),

          // ── Education section ──────────────────────────────────────────────
          _buildEducationSection(),
          const SizedBox(height: 12),

          // ── Certifications section ─────────────────────────────────────────
          _buildCertificationsSection(),
          const SizedBox(height: 12),

          // ── Resume Upload ──────────────────────────────────────────────────
          _buildResumeSection(),
          const SizedBox(height: 12),

          // ── Portfolio Description ──────────────────────────────────────────
          _buildSectionCard(
            title: 'Portfolio *',
            subtitle:
                'Describe your past work, projects, or achievements. This will be shown on your freelancer profile.',
            child: TextFormField(
              controller: _portfolioDescController,
              minLines: 4,
              maxLines: 12,
              maxLength: 3000,
              decoration: const InputDecoration(
                hintText:
                    'e.g. "I redesigned the e-commerce checkout flow for XYZ company, increasing conversion by 30%..."',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Portfolio description is required';
                }
                if (v.trim().length < 50) {
                  return 'Please provide at least 50 characters';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── Why become a freelancer? ───────────────────────────────────────
          _buildSectionCard(
            title: 'Why Do You Want to Become a Freelancer?',
            subtitle: 'Tell us your motivation (required).',
            child: TextFormField(
              controller: _motivationController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText:
                    'Tell us about your goals and what drives you to freelance...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 20) {
                  return 'Please provide at least 20 characters';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Error message ──────────────────────────────────────────────────
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Submit button ──────────────────────────────────────────────────
          FilledButton.icon(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_isLoading ? 'Submitting...' : 'Submit Request'),
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Resume Upload ─────────────────────────────────────────────────────────
  Widget _buildResumeSection() {
    final fileName = _resumePath != null ? _resumePath!.split('/').last : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resume / CV *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Upload your resume in PDF format. Required.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            if (_resumePath != null && File(_resumePath!).existsSync()) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName ?? 'resume',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text('Uploaded',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.green)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.grey),
                      tooltip: 'Remove',
                      onPressed: () =>
                          setState(() => _resumePath = null),
                    ),
                    IconButton(
                      icon: const Icon(Icons.upload_file,
                          size: 18, color: Colors.green),
                      tooltip: 'Replace',
                      onPressed:
                          _isUploadingResume ? null : _pickResume,
                    ),
                  ],
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: _isUploadingResume
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(_isUploadingResume
                    ? 'Uploading...'
                    : 'Upload Resume (PDF only)'),
                onPressed:
                    _isUploadingResume ? null : _pickResume,
              ),
            ],
            if (_resumeError != null) ...[
              const SizedBox(height: 6),
              _InlineError(_resumeError!),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section card wrapper ─────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ── Skills & Expertise ────────────────────────────────────────────────────
  Widget _buildSkillsSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Skills & Expertise *',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Add the skills you offer to clients. At least 1 required.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            if (_skills.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _skills.map((s) {
                  return Chip(
                    label: Text('${s.skill} (${s.level})'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _skills.remove(s));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (_showSkillForm)
              _buildSkillInlineForm()
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Skill'),
                onPressed: () => setState(() {
                  _showSkillForm = true;
                  _resetSkillForm();
                }),
              ),
            if (_skillsError != null) ...[
              const SizedBox(height: 6),
              _InlineError(_skillsError!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkillInlineForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _skillNameController,
            onChanged: (_) {
              if (_skillNameError != null) {
                setState(() => _skillNameError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Skill name *',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _skillNameError,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _skillLevel,
            decoration: const InputDecoration(
              labelText: 'Level',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
              DropdownMenuItem(
                  value: 'Intermediate', child: Text('Intermediate')),
              DropdownMenuItem(value: 'Expert', child: Text('Expert')),
            ],
            onChanged: (v) => setState(() => _skillLevel = v ?? 'Beginner'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: () {
                  final name = _skillNameController.text.trim();
                  if (name.isEmpty) {
                    setState(() => _skillNameError = 'Skill name is required');
                    return;
                  }
                  setState(() {
                    _skills.add(
                        SkillWithLevel(skill: name, level: _skillLevel));
                    _showSkillForm = false;
                    _skillsError = null;
                    _resetSkillForm();
                  });
                },
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _showSkillForm = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Work Experience ───────────────────────────────────────────────────────
  Widget _buildWorkExperienceSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Work Experience *',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Add your relevant work history. At least 1 required.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            if (_workExperiences.isNotEmpty) ...[
              ..._workExperiences.map((w) => _buildWorkCard(w)),
              const SizedBox(height: 8),
            ],
            if (_showWorkForm)
              _buildWorkInlineForm()
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Work Experience'),
                onPressed: () => setState(() {
                  _showWorkForm = true;
                  _resetWorkForm();
                }),
              ),
            if (_workError != null) ...[
              const SizedBox(height: 6),
              _InlineError(_workError!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkCard(WorkExperience w) {
    final index = _workExperiences.indexOf(w);
    final dates = [
      if (w.startDate != null) w.startDate!,
      if (w.currentlyWorkHere) 'Present' else if (w.endDate != null) w.endDate!,
    ].join(' – ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey.shade50,
      child: ListTile(
        title: Text(w.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${w.company}${dates.isNotEmpty ? '  •  $dates' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: () => setState(() {
                _editingWorkIndex = index;
                _populateWorkForm(w);
                _showWorkForm = true;
              }),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete',
              onPressed: () async {
                final confirmed = await _confirmRemove(
                    'Work Experience', '${w.title} at ${w.company}');
                if (confirmed) setState(() => _workExperiences.remove(w));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkInlineForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job Title
          TextField(
            controller: _workTitleController,
            onChanged: (_) {
              if (_workTitleError != null) {
                setState(() => _workTitleError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Job Title *',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _workTitleError,
            ),
          ),
          const SizedBox(height: 8),

          // Employment Type
          DropdownButtonFormField<String>(
            initialValue: _workEmploymentType,
            decoration: const InputDecoration(
              labelText: 'Employment Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'Full-time', child: Text('Full-time')),
              DropdownMenuItem(value: 'Part-time', child: Text('Part-time')),
              DropdownMenuItem(value: 'Freelance', child: Text('Freelance')),
              DropdownMenuItem(value: 'Contract', child: Text('Contract')),
              DropdownMenuItem(value: 'Internship', child: Text('Internship')),
            ],
            onChanged: (v) => setState(() => _workEmploymentType = v),
            hint: const Text('Select type'),
          ),
          const SizedBox(height: 8),

          // Company
          TextField(
            controller: _workCompanyController,
            onChanged: (_) {
              if (_workCompanyError != null) {
                setState(() => _workCompanyError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Company *',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _workCompanyError,
            ),
          ),
          const SizedBox(height: 4),

          // Currently work here checkbox
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I currently work here'),
            value: _workCurrently,
            onChanged: (v) => setState(() {
              _workCurrently = v ?? false;
              if (_workCurrently) _workEndDate = null;
            }),
            controlAffinity: ListTileControlAffinity.leading,
          ),

          // Start Date picker — cannot be in the future
          GestureDetector(
            onTap: () async {
              final picked = await _pickMonthYear(
                _workStartDate,
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _workStartDate = picked;
                  _workStartError = null;
                });
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Start Date *',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _workStartError,
                suffixIcon: _workStartDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            setState(() => _workStartDate = null),
                      )
                    : const Icon(Icons.calendar_month_outlined, size: 18),
              ),
              isEmpty: _workStartDate == null,
              child: Text(
                _workStartDate != null
                    ? _fmtMonthYear(_workStartDate!)
                    : '',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),

          // End Date picker (hidden when currently working) — cannot be in the future
          if (!_workCurrently) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await _pickMonthYear(
                  _workEndDate,
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _workEndDate = picked;
                    _workEndError = null;
                  });
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'End Date *',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: _workEndError,
                  suffixIcon: _workEndDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => _workEndDate = null),
                        )
                      : const Icon(Icons.calendar_month_outlined, size: 18),
                ),
                isEmpty: _workEndDate == null,
                child: Text(
                  _workEndDate != null ? _fmtMonthYear(_workEndDate!) : '',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Description
          TextField(
            controller: _workDescController,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),

          // Industry
          TextField(
            controller: _workIndustryController,
            decoration: const InputDecoration(
              labelText: 'Industry',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              FilledButton(
                onPressed: () {
                  final title = _workTitleController.text.trim();
                  final company = _workCompanyController.text.trim();
                  // Validate required fields
                  bool hasError = false;
                  if (title.isEmpty) {
                    setState(() => _workTitleError = 'Job title is required');
                    hasError = true;
                  }
                  if (company.isEmpty) {
                    setState(
                        () => _workCompanyError = 'Company name is required');
                    hasError = true;
                  }
                  if (_workStartDate == null) {
                    setState(() => _workStartError = 'Start date is required');
                    hasError = true;
                  }
                  if (!_workCurrently && _workEndDate == null) {
                    setState(() => _workEndError = 'End date is required');
                    hasError = true;
                  }
                  // Start date must not be in the future
                  final now = DateTime.now();
                  final currentMonth = DateTime(now.year, now.month);
                  if (_workStartDate != null) {
                    final startMonth = DateTime(
                        _workStartDate!.year, _workStartDate!.month);
                    if (startMonth.isAfter(currentMonth)) {
                      setState(() => _workStartError =
                          'Start date cannot be in the future');
                      hasError = true;
                    }
                  }
                  // End date must not be in the future
                  if (!_workCurrently && _workEndDate != null) {
                    final endMonth = DateTime(
                        _workEndDate!.year, _workEndDate!.month);
                    if (endMonth.isAfter(currentMonth)) {
                      setState(() => _workEndError =
                          'End date cannot be in the future');
                      hasError = true;
                    }
                  }
                  // End date must be after start date
                  if (!_workCurrently &&
                      _workStartDate != null &&
                      _workEndDate != null) {
                    final startMonth =
                        DateTime(_workStartDate!.year, _workStartDate!.month);
                    final endMonth =
                        DateTime(_workEndDate!.year, _workEndDate!.month);
                    if (!endMonth.isAfter(startMonth)) {
                      setState(() =>
                          _workEndError = 'End date must be after start date');
                      hasError = true;
                    }
                  }
                  if (hasError) return;
                  final entry = WorkExperience(
                    title: title,
                    company: company,
                    employmentType: _workEmploymentType,
                    currentlyWorkHere: _workCurrently,
                    startDate: _fmtMonthYear(_workStartDate!),
                    endDate: _workCurrently || _workEndDate == null
                        ? null
                        : _fmtMonthYear(_workEndDate!),
                    description: _workDescController.text.trim().isEmpty
                        ? null
                        : _workDescController.text.trim(),
                    industry: _workIndustryController.text.trim().isEmpty
                        ? null
                        : _workIndustryController.text.trim(),
                  );
                  setState(() {
                    if (_editingWorkIndex != null) {
                      _workExperiences[_editingWorkIndex!] = entry;
                      _editingWorkIndex = null;
                    } else {
                      _workExperiences.add(entry);
                    }
                    _showWorkForm = false;
                    _workError = null;
                    _resetWorkForm();
                  });
                },
                child: Text(_editingWorkIndex != null ? 'Save' : 'Add'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                  _showWorkForm = false;
                  _editingWorkIndex = null;
                  _resetWorkForm();
                }),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Education ─────────────────────────────────────────────────────────────
  Widget _buildEducationSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Education *',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Add your educational background. At least 1 required.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            if (_educations.isNotEmpty) ...[
              ..._educations.map((e) => _buildEducationCard(e)),
              const SizedBox(height: 8),
            ],
            if (_showEducationForm)
              _buildEducationInlineForm()
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Education'),
                onPressed: () => setState(() {
                  _showEducationForm = true;
                  _resetEduForm();
                }),
              ),
            if (_eduError != null) ...[
              const SizedBox(height: 6),
              _InlineError(_eduError!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEducationCard(EducationItem e) {
    final index = _educations.indexOf(e);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey.shade50,
      child: ListTile(
        title: Text(e.school,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          if (e.degree != null) e.degree!,
          if (e.fieldOfStudy != null) e.fieldOfStudy!,
          e.country,
          if (e.yearOfGraduation != null) '${e.yearOfGraduation}',
        ].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: () => setState(() {
                _editingEduIndex = index;
                _populateEduForm(e);
                _showEducationForm = true;
              }),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete',
              onPressed: () async {
                final confirmed =
                    await _confirmRemove('Education', e.school);
                if (confirmed) setState(() => _educations.remove(e));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationInlineForm() {
    final currentYear = DateTime.now().year;
    final years = List.generate(
        currentYear - 1969, (i) => currentYear - i);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => showCountryPicker(
              context: context,
              showPhoneCode: false,
              onSelect: (Country c) =>
                  setState(() => _eduCountry = c.name),
            ),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Country *',
                border: OutlineInputBorder(),
                isDense: true,
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(_eduCountry,
                  style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _eduSchoolController,
            onChanged: (_) {
              if (_eduSchoolError != null) {
                setState(() => _eduSchoolError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'School / University *',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _eduSchoolError,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _eduDegree,
            decoration: const InputDecoration(
              labelText: 'Degree',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                  value: 'High School', child: Text('High School')),
              DropdownMenuItem(
                  value: 'Diploma', child: Text('Diploma')),
              DropdownMenuItem(
                  value: "Bachelor's", child: Text("Bachelor's")),
              DropdownMenuItem(
                  value: "Master's", child: Text("Master's")),
              DropdownMenuItem(value: 'PhD', child: Text('PhD')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _eduDegree = v),
            hint: const Text('Select degree'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _eduFieldController,
            decoration: const InputDecoration(
              labelText: 'Field of Study',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _eduYear,
            decoration: const InputDecoration(
              labelText: 'Year of Graduation',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: years
                .map((y) =>
                    DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _eduYear = v),
            hint: const Text('Select year'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: () {
                  final school = _eduSchoolController.text.trim();
                  if (school.isEmpty) {
                    setState(
                        () => _eduSchoolError = 'School name is required');
                    return;
                  }
                  final entry = EducationItem(
                    country: _eduCountry,
                    school: school,
                    degree: _eduDegree,
                    fieldOfStudy: _eduFieldController.text.trim().isEmpty
                        ? null
                        : _eduFieldController.text.trim(),
                    yearOfGraduation: _eduYear,
                  );
                  setState(() {
                    if (_editingEduIndex != null) {
                      _educations[_editingEduIndex!] = entry;
                      _editingEduIndex = null;
                    } else {
                      _educations.add(entry);
                    }
                    _showEducationForm = false;
                    _eduError = null;
                    _resetEduForm();
                  });
                },
                child: Text(_editingEduIndex != null ? 'Save' : 'Add'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                  _showEducationForm = false;
                  _editingEduIndex = null;
                  _resetEduForm();
                }),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Certifications ────────────────────────────────────────────────────────
  Widget _buildCertificationsSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Certifications',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Optional. Add any certifications or awards you have received.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            if (_certifications.isNotEmpty) ...[
              ..._certifications.map((c) => _buildCertCard(c)),
              const SizedBox(height: 8),
            ],
            if (_showCertForm)
              _buildCertInlineForm()
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Certification'),
                onPressed: () => setState(() {
                  _showCertForm = true;
                  _resetCertForm();
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertCard(CertificationItem c) {
    final index = _certifications.indexOf(c);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey.shade50,
      child: ListTile(
        title: Text(c.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          if (c.issuedBy != null) c.issuedBy!,
          if (c.yearReceived != null) '${c.yearReceived}',
        ].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: () => setState(() {
                _editingCertIndex = index;
                _populateCertForm(c);
                _showCertForm = true;
              }),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete',
              onPressed: () async {
                final confirmed =
                    await _confirmRemove('Certification', c.name);
                if (confirmed) setState(() => _certifications.remove(c));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertInlineForm() {
    final currentYear = DateTime.now().year;
    final years = List.generate(
        currentYear - 1969, (i) => currentYear - i);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _certNameController,
            onChanged: (_) {
              if (_certNameError != null) {
                setState(() => _certNameError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Certificate / Award Name *',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _certNameError,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _certIssuedByController,
            decoration: const InputDecoration(
              labelText: 'Received from',
              hintText: 'e.g. Adobe, Google',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _certYear,
            decoration: const InputDecoration(
              labelText: 'Year Received',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: years
                .map((y) =>
                    DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _certYear = v),
            hint: const Text('Select year'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: () {
                  final name = _certNameController.text.trim();
                  if (name.isEmpty) {
                    setState(
                        () => _certNameError = 'Certificate name is required');
                    return;
                  }
                  final entry = CertificationItem(
                    name: name,
                    issuedBy: _certIssuedByController.text.trim().isEmpty
                        ? null
                        : _certIssuedByController.text.trim(),
                    yearReceived: _certYear,
                  );
                  setState(() {
                    if (_editingCertIndex != null) {
                      _certifications[_editingCertIndex!] = entry;
                      _editingCertIndex = null;
                    } else {
                      _certifications.add(entry);
                    }
                    _showCertForm = false;
                    _resetCertForm();
                  });
                },
                child: Text(_editingCertIndex != null ? 'Save' : 'Add'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                  _showCertForm = false;
                  _editingCertIndex = null;
                  _resetCertForm();
                }),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Inline error text (matches Flutter's TextFormField error style) ───────────

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error_outline,
            size: 13, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month / Year Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({this.initialDate, this.lastDate});
  final DateTime? initialDate;
  /// When set, the user cannot pick any month/year after this date.
  final DateTime? lastDate;

  @override
  State<_MonthYearPickerDialog> createState() =>
      _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _month;

  static const _monthNames = [
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    // Clamp initial date to lastDate if needed
    DateTime d = widget.initialDate ?? DateTime.now();
    if (widget.lastDate != null) {
      final last = widget.lastDate!;
      if (d.year > last.year ||
          (d.year == last.year && d.month > last.month)) {
        d = DateTime(last.year, last.month);
      }
    }
    _year = d.year;
    _month = d.month;
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.lastDate ?? DateTime(DateTime.now().year + 50);
    final maxYear = last.year;
    // Build year list from maxYear down to 1970
    final years = List.generate(maxYear - 1969, (i) => maxYear - i);
    // When the selected year equals the cap year, limit months
    final maxMonth = _year == last.year ? last.month : 12;
    // Clamp current month selection if year was changed to cap year
    final safeMonth = _month.clamp(1, maxMonth);

    return AlertDialog(
      title: const Text('Select Month & Year'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: Row(
        children: [
          // Month dropdown — limited to maxMonth when on the cap year
          Expanded(
            flex: 3,
            child: DropdownButton<int>(
              value: safeMonth,
              isExpanded: true,
              items: List.generate(
                maxMonth,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_monthNames[i]),
                ),
              ),
              onChanged: (v) => setState(() => _month = v!),
            ),
          ),
          const SizedBox(width: 12),
          // Year dropdown — capped at maxYear
          Expanded(
            flex: 2,
            child: DropdownButton<int>(
              value: _year,
              isExpanded: true,
              items: years
                  .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text('$y'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _year = v;
                  // If switching to cap year, clamp month
                  if (widget.lastDate != null && v == widget.lastDate!.year) {
                    _month = _month.clamp(1, widget.lastDate!.month);
                  }
                });
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, DateTime(_year, safeMonth)),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
