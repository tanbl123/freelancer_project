import '../../../backend/shared/domain_types.dart';

class ApplicationItem {
  const ApplicationItem({
    required this.id,
    required this.jobId,
    required this.clientId,
    required this.freelancerId,
    required this.freelancerName,
    required this.proposalMessage,
    required this.expectedBudget,
    required this.timelineDays,
    required this.status,
    this.resumeUrl,
    this.voicePitchUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String jobId;
  final String clientId;
  final String freelancerId;
  final String freelancerName;
  final String proposalMessage;
  final double expectedBudget;
  final int timelineDays;
  final ApplicationStatus status;
  final String? resumeUrl;
  final String? voicePitchUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Supabase map (ISO 8601) ──────────────────────────────────────────────────
  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'job_id': jobId,
      'client_id': clientId,
      'freelancer_id': freelancerId,
      'freelancer_name': freelancerName,
      'proposal_message': proposalMessage,
      'expected_budget': expectedBudget,
      'timeline_days': timelineDays,
      'status': status.name,
      'resume_url': resumeUrl,
      'voice_pitch_url': voicePitchUrl,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  // ── SQLite map (epoch ms) ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'job_id': jobId,
      'client_id': clientId,
      'freelancer_id': freelancerId,
      'freelancer_name': freelancerName,
      'proposal_message': proposalMessage,
      'expected_budget': expectedBudget,
      'timeline_days': timelineDays,
      'status': status.name,
      'resume_url': resumeUrl,
      'voice_pitch_url': voicePitchUrl,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  // ── Dual-format fromMap ──────────────────────────────────────────────────────
  factory ApplicationItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ApplicationItem(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      clientId: map['client_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      freelancerName: map['freelancer_name'] as String,
      proposalMessage: map['proposal_message'] as String,
      expectedBudget: (map['expected_budget'] as num).toDouble(),
      timelineDays: (map['timeline_days'] as num).toInt(),
      status: ApplicationStatus.values
          .byName(map['status'] as String? ?? 'pending'),
      resumeUrl: map['resume_url'] as String?,
      voicePitchUrl: map['voice_pitch_url'] as String?,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  ApplicationItem copyWith({
    String? proposalMessage,
    double? expectedBudget,
    int? timelineDays,
    ApplicationStatus? status,
    String? resumeUrl,
    String? voicePitchUrl,
  }) {
    return ApplicationItem(
      id: id,
      jobId: jobId,
      clientId: clientId,
      freelancerId: freelancerId,
      freelancerName: freelancerName,
      proposalMessage: proposalMessage ?? this.proposalMessage,
      expectedBudget: expectedBudget ?? this.expectedBudget,
      timelineDays: timelineDays ?? this.timelineDays,
      status: status ?? this.status,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      voicePitchUrl: voicePitchUrl ?? this.voicePitchUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
