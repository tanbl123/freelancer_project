import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../backend/shared/domain_types.dart';

class MarketplacePost {
  const MarketplacePost({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.minimumBudget,
    required this.deadline,
    required this.skills,
    required this.type,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.isAccepted = false,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String description;
  final double minimumBudget;
  final DateTime deadline;
  final List<String> skills;
  final PostType type;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAccepted;

  bool get isExpired => deadline.isBefore(DateTime.now());

  factory MarketplacePost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MarketplacePost(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      minimumBudget: (data['minimumBudget'] as num?)?.toDouble() ?? 0,
      deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      skills: List<String>.from(data['skills'] as List? ?? const []),
      type: PostType.values.byName(data['type'] as String? ?? PostType.jobRequest.name),
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isAccepted: data['isAccepted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'title': title,
      'description': description,
      'minimumBudget': minimumBudget,
      'deadline': Timestamp.fromDate(deadline),
      'skills': skills,
      'type': type.name,
      'imageUrl': imageUrl,
      'isAccepted': isAccepted,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
