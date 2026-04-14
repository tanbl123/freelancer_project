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
  final String? jobTitle;      // denormalized for display
  final String? clientName;    // denormalized for display
  final String? freelancerName; // denormalized for display
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == 'completed';

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

  factory ProjectItem.fromMap(Map<String, dynamic> map) {
    return ProjectItem(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      applicationId: map['application_id'] as String,
      clientId: map['client_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      status: map['status'] as String? ?? 'inProgress',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
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
