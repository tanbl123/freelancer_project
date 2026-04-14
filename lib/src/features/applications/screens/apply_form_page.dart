import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../services/file_storage_service.dart';
import '../../../state/app_state.dart';
import '../../marketplace/models/marketplace_post.dart';
import '../models/application_item.dart';

class ApplyFormPage extends StatefulWidget {
  const ApplyFormPage({super.key, this.existing, this.preselectedPost});
  final ApplicationItem? existing;
  final MarketplacePost? preselectedPost;

  @override
  State<ApplyFormPage> createState() => _ApplyFormPageState();
}

class _ApplyFormPageState extends State<ApplyFormPage> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _proposalController = TextEditingController();
  final _budgetController = TextEditingController();
  final _daysController = TextEditingController();

  bool _isLoading = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _selectedJobId;
  String? _resumePath;
  String? _voicePitchPath;

  late final AudioRecorder _recorder;
  late final AudioPlayer _player;
  List<MarketplacePost> _availableJobs = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _player = AudioPlayer();
    _loadJobs();
    if (_isEditing) {
      final a = widget.existing!;
      _selectedJobId = a.jobId;
      _proposalController.text = a.proposalMessage;
      _budgetController.text = a.expectedBudget.toStringAsFixed(0);
      _daysController.text = a.timelineDays.toString();
      _resumePath = a.resumeUrl;
      _voicePitchPath = a.voicePitchUrl;
    } else if (widget.preselectedPost != null) {
      _selectedJobId = widget.preselectedPost!.id;
    }
  }

  void _loadJobs() {
    setState(() {
      _availableJobs = AppState.instance.posts
          .where((p) =>
              p.type == PostType.jobRequest &&
              !p.isExpired &&
              !p.isAccepted)
          .toList();
    });
  }

  @override
  void dispose() {
    _proposalController.dispose();
    _budgetController.dispose();
    _daysController.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      if (path != null) {
        final saved =
            await FileStorageService.instance.saveAudio(path, 'voice_pitches');
        setState(() {
          _voicePitchPath = saved;
          _isRecording = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice pitch recorded!')),
          );
        }
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Microphone permission denied.')),
            );
          }
          return;
        }
      }
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _togglePlayback() async {
    if (_voicePitchPath == null ||
        !FileStorageService.instance.fileExists(_voicePitchPath)) {
      return;
    }
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await _player.play(DeviceFileSource(_voicePitchPath!));
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
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
    final job = AppState.instance.posts
        .firstWhere((p) => p.id == _selectedJobId, orElse: () {
      return AppState.instance.posts.first;
    });

    String? error;
    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        proposalMessage: _proposalController.text.trim(),
        expectedBudget: double.parse(_budgetController.text),
        timelineDays: int.parse(_daysController.text),
        resumeUrl: _resumePath,
        voicePitchUrl: _voicePitchPath,
      );
      await AppState.instance.updateApplication(updated);
    } else {
      final app = ApplicationItem(
        id: _uuid.v4(),
        jobId: _selectedJobId!,
        clientId: job.ownerId,
        freelancerId: user.uid,
        freelancerName: user.displayName,
        proposalMessage: _proposalController.text.trim(),
        expectedBudget: double.parse(_budgetController.text),
        timelineDays: int.parse(_daysController.text),
        status: ApplicationStatus.pending,
        resumeUrl: _resumePath,
        voicePitchUrl: _voicePitchPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      error = await AppState.instance.addApplication(app);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _isEditing ? 'Application updated!' : 'Application submitted!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit Application' : 'Submit Application')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Job selector
              if (!_isEditing)
                DropdownButtonFormField<String>(
                  initialValue: _selectedJobId,
                  decoration: const InputDecoration(
                    labelText: 'Select Job *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: _availableJobs
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
              if (!_isEditing) const SizedBox(height: 12),

              TextFormField(
                controller: _proposalController,
                decoration: const InputDecoration(
                  labelText: 'Proposal Message *',
                  border: OutlineInputBorder(),
                  hintText: 'Describe your approach, experience, and why you\'re the best fit...',
                ),
                maxLines: 5,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Proposal is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Your Quote (RM) *',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Quote is required';
                  if (double.tryParse(v) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _daysController,
                decoration: const InputDecoration(
                  labelText: 'Timeline (days) *',
                  border: OutlineInputBorder(),
                  suffixText: 'days',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Timeline is required';
                  if (int.tryParse(v) == null || int.parse(v) <= 0) {
                    return 'Enter a valid number of days';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Resume upload
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resume / CV',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (_resumePath != null &&
                          FileStorageService.instance.fileExists(_resumePath))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.description, color: Colors.blue),
                          title: Text(
                            _resumePath!.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text('Tap to change'),
                          onTap: _pickResume,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
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
              const SizedBox(height: 12),

              // Voice pitch recording
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Voice Pitch (Optional)',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Text('Record a short introduction to stand out',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _toggleRecording,
                            icon: Icon(
                                _isRecording ? Icons.stop : Icons.mic),
                            label: Text(
                                _isRecording ? 'Stop Recording' : 'Record'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _isRecording
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                          if (_voicePitchPath != null &&
                              FileStorageService.instance
                                  .fileExists(_voicePitchPath)) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _togglePlayback,
                              icon: Icon(
                                  _isPlaying ? Icons.stop : Icons.play_arrow),
                              label: Text(_isPlaying ? 'Stop' : 'Play'),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () =>
                                  setState(() => _voicePitchPath = null),
                            ),
                          ],
                        ],
                      ),
                      if (_isRecording)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  color: Colors.red, size: 14),
                              SizedBox(width: 6),
                              Text('Recording...',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
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
                    : Text(_isEditing ? 'Save Changes' : 'Submit Application',
                        style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
