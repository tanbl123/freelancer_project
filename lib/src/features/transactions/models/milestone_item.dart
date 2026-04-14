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
    this.deliverableUrl,
    this.clientSignatureUrl,
    this.paymentToken,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String description;
  final DateTime deadline;
  final double paymentAmount;
  final MilestoneStatus status;
  final String? deliverableUrl;
  final String? clientSignatureUrl;
  final String? paymentToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLocked =>
      status == MilestoneStatus.approved || status == MilestoneStatus.locked;

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
      'deliverable_url': deliverableUrl,
      'client_signature_url': clientSignatureUrl,
      'payment_token': paymentToken,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  factory MilestoneItem.fromMap(Map<String, dynamic> map) {
    return MilestoneItem(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      deadline: DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int),
      paymentAmount: (map['payment_amount'] as num).toDouble(),
      status: MilestoneStatus.values
          .byName(map['status'] as String? ?? 'draft'),
      deliverableUrl: map['deliverable_url'] as String?,
      clientSignatureUrl: map['client_signature_url'] as String?,
      paymentToken: map['payment_token'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }

  MilestoneItem copyWith({
    String? title,
    String? description,
    DateTime? deadline,
    double? paymentAmount,
    MilestoneStatus? status,
    String? deliverableUrl,
    String? clientSignatureUrl,
    String? paymentToken,
  }) {
    return MilestoneItem(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      status: status ?? this.status,
      deliverableUrl: deliverableUrl ?? this.deliverableUrl,
      clientSignatureUrl: clientSignatureUrl ?? this.clientSignatureUrl,
      paymentToken: paymentToken ?? this.paymentToken,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
