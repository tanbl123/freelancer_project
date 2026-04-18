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

  // Inline form toggles
  bool _showSkillForm = false;
  bool _showWorkForm = false;
  bool _showEducationForm = false;
  bool _showCertForm = false;

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

  // ── Resume picker ─────────────────────────────────────────────────────────
  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _isUploadingResume = true);
    try {
      final saved = await FileStorageService.instance
          .savePlatformFile(result.files.first, 'resumes');
      setState(() => _resumePath = saved);
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
  Future<DateTime?> _pickMonthYear(DateTime? initial) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearPickerDialog(initialDate: initial),
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
    if (!_formKey.currentState!.validate()) return;
    if (_skills.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one skill.');
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request submitted! An admin will review it soon.')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final existing = AppState.instance.myFreelancerRequest;

        return Scaffold(
          appBar: AppBar(title: const Text('Become a Freelancer')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: existing != null
                ? _buildStatusView(existing.status, existing.adminNote)
                : _buildForm(),
          ),
        );
      },
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
              onPressed: () => setState(() {}),
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
            const Text('Resume / CV',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Optional. Upload your resume (PDF, DOC, or DOCX).',
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
                    : 'Upload Resume (PDF / DOC / DOCX)'),
                onPressed:
                    _isUploadingResume ? null : _pickResume,
              ),
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
            const Text('Skills & Expertise',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Add the skills you offer to clients (at least 1 required).',
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
            const Text('Work Experience',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Optional. Add your relevant work history.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildWorkCard(WorkExperience w) {
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
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () =>
              setState(() => _workExperiences.remove(w)),
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

          // Start Date picker
          GestureDetector(
            onTap: () async {
              final picked = await _pickMonthYear(_workStartDate);
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

          // End Date picker (hidden when currently working)
          if (!_workCurrently) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await _pickMonthYear(_workEndDate);
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
                  setState(() {
                    _workExperiences.add(WorkExperience(
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
                    ));
                    _showWorkForm = false;
                    _resetWorkForm();
                  });
                },
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() {
                  _showWorkForm = false;
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
            const Text('Education',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Optional. Add your educational background.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildEducationCard(EducationItem e) {
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
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () =>
              setState(() => _educations.remove(e)),
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
                  setState(() {
                    _educations.add(EducationItem(
                      country: _eduCountry,
                      school: school,
                      degree: _eduDegree,
                      fieldOfStudy:
                          _eduFieldController.text.trim().isEmpty
                              ? null
                              : _eduFieldController.text.trim(),
                      yearOfGraduation: _eduYear,
                    ));
                    _showEducationForm = false;
                    _resetEduForm();
                  });
                },
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _showEducationForm = false),
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
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () =>
              setState(() => _certifications.remove(c)),
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
                  setState(() {
                    _certifications.add(CertificationItem(
                      name: name,
                      issuedBy:
                          _certIssuedByController.text.trim().isEmpty
                              ? null
                              : _certIssuedByController.text.trim(),
                      yearReceived: _certYear,
                    ));
                    _showCertForm = false;
                    _resetCertForm();
                  });
                },
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _showCertForm = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month / Year Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({this.initialDate});
  final DateTime? initialDate;

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
    final d = widget.initialDate ?? DateTime.now();
    _year = d.year;
    _month = d.month;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 1969, (i) => currentYear - i);

    return AlertDialog(
      title: const Text('Select Month & Year'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: Row(
        children: [
          // Month dropdown
          Expanded(
            flex: 3,
            child: DropdownButton<int>(
              value: _month,
              isExpanded: true,
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_monthNames[i]),
                ),
              ),
              onChanged: (v) => setState(() => _month = v!),
            ),
          ),
          const SizedBox(width: 12),
          // Year dropdown
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
              onChanged: (v) => setState(() => _year = v!),
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
              Navigator.pop(context, DateTime(_year, _month)),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
