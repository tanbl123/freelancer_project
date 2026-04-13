import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory ApplicationItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ApplicationItem(
      id: doc.id,
      jobId: data['jobId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      freelancerId: data['freelancerId'] as String? ?? '',
      freelancerName: data['freelancerName'] as String? ?? '',
      proposalMessage: data['proposalMessage'] as String? ?? '',
      expectedBudget: (data['expectedBudget'] as num?)?.toDouble() ?? 0,
      timelineDays: data['timelineDays'] as int? ?? 0,
      status: ApplicationStatus.values.byName(data['status'] as String? ?? ApplicationStatus.pending.name),
      resumeUrl: data['resumeUrl'] as String?,
      voicePitchUrl: data['voicePitchUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'proposalMessage': proposalMessage,
      'expectedBudget': expectedBudget,
      'timelineDays': timelineDays,
      'status': status.name,
      'resumeUrl': resumeUrl,
      'voicePitchUrl': voicePitchUrl,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
