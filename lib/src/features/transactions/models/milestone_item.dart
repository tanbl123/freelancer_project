import 'package:cloud_firestore/cloud_firestore.dart';

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

  bool get isLocked => status == MilestoneStatus.approved || status == MilestoneStatus.locked;

  factory MilestoneItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MilestoneItem(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentAmount: (data['paymentAmount'] as num?)?.toDouble() ?? 0,
      status: MilestoneStatus.values.byName(data['status'] as String? ?? MilestoneStatus.draft.name),
      deliverableUrl: data['deliverableUrl'] as String?,
      clientSignatureUrl: data['clientSignatureUrl'] as String?,
      paymentToken: data['paymentToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'deadline': Timestamp.fromDate(deadline),
      'paymentAmount': paymentAmount,
      'status': status.name,
      'deliverableUrl': deliverableUrl,
      'clientSignatureUrl': clientSignatureUrl,
      'paymentToken': paymentToken,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
