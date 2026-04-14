class ProjectItem {
  const ProjectItem({
    required this.id,
    required this.jobId,
    required this.applicationId,
    required this.clientId,
    required this.freelancerId,
    required this.status,
    this.jobTitle,
    this.clientName,
    this.freelancerName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String jobId;
  final String applicationId;
  final String clientId;
  final String freelancerId;
  final String status; // 'inProgress' | 'completed' | 'cancelled'
  final String? jobTitle;
  final String? clientName;
  final String? freelancerName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == 'completed';

  // ── Supabase map (ISO 8601) ──────────────────────────────────────────────────
  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'job_id': jobId,
      'application_id': applicationId,
      'client_id': clientId,
      'freelancer_id': freelancerId,
      'status': status,
      'job_title': jobTitle,
      'client_name': clientName,
      'freelancer_name': freelancerName,
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
      'application_id': applicationId,
      'client_id': clientId,
      'freelancer_id': freelancerId,
      'status': status,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  // ── Dual-format fromMap ──────────────────────────────────────────────────────
  factory ProjectItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ProjectItem(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      applicationId: map['application_id'] as String,
      clientId: map['client_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      status: map['status'] as String? ?? 'inProgress',
      jobTitle: map['job_title'] as String?,
      clientName: map['client_name'] as String?,
      freelancerName: map['freelancer_name'] as String?,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  ProjectItem copyWith({
    String? status,
    String? jobTitle,
    String? clientName,
    String? freelancerName,
  }) {
    return ProjectItem(
      id: id,
      jobId: jobId,
      applicationId: applicationId,
      clientId: clientId,
      freelancerId: freelancerId,
      status: status ?? this.status,
      jobTitle: jobTitle ?? this.jobTitle,
      clientName: clientName ?? this.clientName,
      freelancerName: freelancerName ?? this.freelancerName,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
