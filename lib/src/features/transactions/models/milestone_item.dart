import '../../../backend/shared/domain_types.dart';

class MilestoneItem {
  const MilestoneItem({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.paymentAmount,
    required this.status,
    required this.percentage,
    required this.orderIndex,
    this.deliverableUrl,
    this.clientSignatureUrl,
    this.paymentToken,
    this.rejectionNote,
    this.revisionCount = 0,
    this.extensionDays,
    this.extensionRequestedAt,
    this.extensionApproved = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String description;
  final DateTime deadline;

  /// Calculated: totalBudget × percentage ÷ 100.
  final double paymentAmount;

  final MilestoneStatus status;

  /// Freelancer-proposed share of the total budget (0–100).
  final double percentage;

  /// 1-based position in the plan. Determines execution order.
  final int orderIndex;

  final String? deliverableUrl;
  final String? clientSignatureUrl;
  final String? paymentToken;

  /// Set by client when rejecting a submitted deliverable.
  final String? rejectionNote;

  /// How many times this milestone has been revised after rejection.
  final int revisionCount;

  /// Approved extension in days (set when client approves the request).
  final int? extensionDays;
  final DateTime? extensionRequestedAt;
  final bool extensionApproved;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  /// True once the client has paid — milestone has a payment token.
  bool get isPaid => paymentToken != null;

  bool get isCompleted => status == MilestoneStatus.completed;
  bool get isInProgress => status == MilestoneStatus.inProgress;
  bool get isSubmitted => status == MilestoneStatus.submitted;
  bool get isRejected => status == MilestoneStatus.rejected;
  bool get isPendingApproval => status == MilestoneStatus.pendingApproval;

  /// Due date accounting for any approved extension.
  DateTime get effectiveDeadline =>
      extensionApproved && extensionDays != null
          ? deadline.add(Duration(days: extensionDays!))
          : deadline;

  bool get isOverdue =>
      !isCompleted &&
      DateTime.now().isAfter(effectiveDeadline);

  // ── Supabase map (ISO 8601) ──────────────────────────────────────────────────
  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'payment_amount': paymentAmount,
      'status': status.name,
      'percentage': percentage,
      'order_index': orderIndex,
      'deliverable_url': deliverableUrl,
      'client_signature_url': clientSignatureUrl,
      'payment_token': paymentToken,
      'rejection_note': rejectionNote,
      'revision_count': revisionCount,
      'extension_days': extensionDays,
      'extension_requested_at': extensionRequestedAt?.toIso8601String(),
      'extension_approved': extensionApproved,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  // ── SQLite map (epoch ms) ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'description': description,
      'deadline': deadline.millisecondsSinceEpoch,
      'payment_amount': paymentAmount,
      'status': status.name,
      'percentage': percentage,
      'order_index': orderIndex,
      'deliverable_url': deliverableUrl,
      'client_signature_url': clientSignatureUrl,
      'payment_token': paymentToken,
      'rejection_note': rejectionNote,
      'revision_count': revisionCount,
      'extension_days': extensionDays,
      'extension_approved': extensionApproved ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  // ── Dual-format fromMap ──────────────────────────────────────────────────────
  factory MilestoneItem.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return MilestoneItem(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      deadline: parseDate(map['deadline']),
      paymentAmount: (map['payment_amount'] as num).toDouble(),
      status: MilestoneStatus.fromString(map['status'] as String? ?? 'pendingApproval'),
      percentage: map['percentage'] == null
          ? 0.0
          : (map['percentage'] as num).toDouble(),
      orderIndex: map['order_index'] == null
          ? 1
          : (map['order_index'] as num).toInt(),
      deliverableUrl: map['deliverable_url'] as String?,
      clientSignatureUrl: map['client_signature_url'] as String?,
      paymentToken: map['payment_token'] as String?,
      rejectionNote: map['rejection_note'] as String?,
      revisionCount: map['revision_count'] == null
          ? 0
          : (map['revision_count'] as num).toInt(),
      extensionDays: map['extension_days'] == null
          ? null
          : (map['extension_days'] as num).toInt(),
      extensionRequestedAt: parseDateNullable(map['extension_requested_at']),
      extensionApproved: map['extension_approved'] == true ||
          map['extension_approved'] == 1,
      createdAt: parseDateNullable(map['created_at']),
      updatedAt: parseDateNullable(map['updated_at']),
    );
  }

  MilestoneItem copyWith({
    String? title,
    String? description,
    DateTime? deadline,
    double? paymentAmount,
    MilestoneStatus? status,
    double? percentage,
    int? orderIndex,
    String? deliverableUrl,
    String? clientSignatureUrl,
    String? paymentToken,
    String? rejectionNote,
    int? revisionCount,
    int? extensionDays,
    DateTime? extensionRequestedAt,
    bool? extensionApproved,
  }) {
    return MilestoneItem(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      status: status ?? this.status,
      percentage: percentage ?? this.percentage,
      orderIndex: orderIndex ?? this.orderIndex,
      deliverableUrl: deliverableUrl ?? this.deliverableUrl,
      clientSignatureUrl: clientSignatureUrl ?? this.clientSignatureUrl,
      paymentToken: paymentToken ?? this.paymentToken,
      rejectionNote: rejectionNote ?? this.rejectionNote,
      revisionCount: revisionCount ?? this.revisionCount,
      extensionDays: extensionDays ?? this.extensionDays,
      extensionRequestedAt: extensionRequestedAt ?? this.extensionRequestedAt,
      extensionApproved: extensionApproved ?? this.extensionApproved,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
