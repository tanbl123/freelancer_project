import '../../../backend/shared/domain_types.dart';

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
    this.sourceType = 'job',
    this.serviceOrderId,
    this.totalBudget,
    this.startDate,
    this.endDate,
    this.description,
    this.clientSignatureUrl,
    this.cancellationReason,
    this.deliveryMode = ProjectDeliveryMode.milestone,
    this.singleDeliverableUrl,
    this.singleRejectionNote,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Originating job post id — empty string for service-order projects.
  final String jobId;

  /// Originating application id — empty string for service-order projects.
  final String applicationId;

  final String clientId;
  final String freelancerId;

  /// Typed project status — replaces the old free-form String.
  final ProjectStatus status;

  final String? jobTitle;
  final String? clientName;
  final String? freelancerName;

  /// 'job' (from a job application) or 'service' (from a service order).
  final String sourceType;

  /// Non-null when [sourceType] == 'service'.
  final String? serviceOrderId;

  /// Total contract value. Milestone amounts are percentages of this.
  final double? totalBudget;

  /// When the project kicked off (plan approved).
  final DateTime? startDate;

  /// Agreed end date (project deadline).
  final DateTime? endDate;

  /// Optional brief description / scope note.
  final String? description;

  /// Client's final digital signature URL — set when project is completed.
  final String? clientSignatureUrl;

  /// Reason provided when the project was cancelled.
  final String? cancellationReason;

  /// How the freelancer delivers work — [ProjectDeliveryMode.milestone] (default)
  /// or [ProjectDeliveryMode.single].
  final ProjectDeliveryMode deliveryMode;

  /// Non-null when [deliveryMode] == [ProjectDeliveryMode.single] and the
  /// freelancer has submitted their deliverable (awaiting client review).
  final String? singleDeliverableUrl;

  /// Set by the client when they reject a single-delivery submission.
  final String? singleRejectionNote;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  bool get isCompleted => status == ProjectStatus.completed;
  bool get isInProgress => status == ProjectStatus.inProgress;
  bool get isPendingStart => status == ProjectStatus.pendingStart;
  bool get isCancelled => status == ProjectStatus.cancelled;
  bool get isDisputed => status == ProjectStatus.disputed;
  bool get isActive =>
      status == ProjectStatus.inProgress || status == ProjectStatus.pendingStart;

  // Single-delivery helpers
  bool get isSingleDelivery => deliveryMode == ProjectDeliveryMode.single;
  /// Freelancer has submitted; awaiting client review.
  bool get isSingleDeliverySubmitted =>
      isSingleDelivery && singleDeliverableUrl != null && !isCompleted;
  /// Client rejected the single-delivery submission.
  bool get isSingleDeliveryRejected =>
      isSingleDelivery && singleRejectionNote != null && singleDeliverableUrl == null;

  // ── Supabase map (ISO 8601) ──────────────────────────────────────────────────
  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'job_id': jobId.isEmpty ? null : jobId,
      'application_id': applicationId.isEmpty ? null : applicationId,
      'client_id': clientId,
      'freelancer_id': freelancerId,
      'status': status.name,
      'job_title': jobTitle,
      'client_name': clientName,
      'freelancer_name': freelancerName,
      'source_type': sourceType,
      'service_order_id': serviceOrderId,
      'total_budget': totalBudget,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'description': description,
      'client_signature_url': clientSignatureUrl,
      'cancellation_reason': cancellationReason,
      'delivery_mode': deliveryMode == ProjectDeliveryMode.single ? 'single' : null,
      'single_deliverable_url': singleDeliverableUrl,
      'single_rejection_note': singleRejectionNote,
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
      'status': status.name,
      'source_type': sourceType,
      'service_order_id': serviceOrderId,
      'total_budget': totalBudget,
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
      jobId: map['job_id'] as String? ?? '',
      applicationId: map['application_id'] as String? ?? '',
      clientId: map['client_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      status: ProjectStatus.fromString(map['status'] as String? ?? 'pendingStart'),
      jobTitle: map['job_title'] as String?,
      clientName: map['client_name'] as String?,
      freelancerName: map['freelancer_name'] as String?,
      sourceType: map['source_type'] as String? ?? 'job',
      serviceOrderId: map['service_order_id'] as String?,
      totalBudget: map['total_budget'] == null
          ? null
          : (map['total_budget'] as num).toDouble(),
      startDate: parseDate(map['start_date']),
      endDate: parseDate(map['end_date']),
      description: map['description'] as String?,
      clientSignatureUrl: map['client_signature_url'] as String?,
      cancellationReason: map['cancellation_reason'] as String?,
      deliveryMode: ProjectDeliveryMode.fromString(map['delivery_mode'] as String?),
      singleDeliverableUrl: map['single_deliverable_url'] as String?,
      singleRejectionNote: map['single_rejection_note'] as String?,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  ProjectItem copyWith({
    ProjectStatus? status,
    String? jobTitle,
    String? clientName,
    String? freelancerName,
    double? totalBudget,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    String? clientSignatureUrl,
    String? cancellationReason,
    ProjectDeliveryMode? deliveryMode,
    Object? singleDeliverableUrl = _sentinel,
    Object? singleRejectionNote = _sentinel,
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
      sourceType: sourceType,
      serviceOrderId: serviceOrderId,
      totalBudget: totalBudget ?? this.totalBudget,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      clientSignatureUrl: clientSignatureUrl ?? this.clientSignatureUrl,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      singleDeliverableUrl: singleDeliverableUrl == _sentinel
          ? this.singleDeliverableUrl
          : singleDeliverableUrl as String?,
      singleRejectionNote: singleRejectionNote == _sentinel
          ? this.singleRejectionNote
          : singleRejectionNote as String?,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static const Object _sentinel = Object();
}
