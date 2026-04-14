import 'dart:convert';

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
    this.isAccepted = false,
    this.createdAt,
    this.updatedAt,
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
  final bool isAccepted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isExpired => deadline.isBefore(DateTime.now());

  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'title': title,
      'description': description,
      'minimum_budget': minimumBudget,
      'deadline': deadline.millisecondsSinceEpoch,
      'skills': jsonEncode(skills),
      'type': type.name,
      'image_url': imageUrl,
      'is_accepted': isAccepted ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  factory MarketplacePost.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic v) {
      if (v == null || v == '') return [];
      try {
        return List<String>.from(jsonDecode(v as String));
      } catch (_) {
        return [];
      }
    }

    return MarketplacePost(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      ownerName: map['owner_name'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      minimumBudget: (map['minimum_budget'] as num).toDouble(),
      deadline: DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int),
      skills: parseList(map['skills']),
      type: PostType.values.byName(map['type'] as String? ?? 'jobRequest'),
      imageUrl: map['image_url'] as String?,
      isAccepted: (map['is_accepted'] as int? ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }

  MarketplacePost copyWith({
    String? title,
    String? description,
    double? minimumBudget,
    DateTime? deadline,
    List<String>? skills,
    PostType? type,
    String? imageUrl,
    bool? isAccepted,
  }) {
    return MarketplacePost(
      id: id,
      ownerId: ownerId,
      ownerName: ownerName,
      title: title ?? this.title,
      description: description ?? this.description,
      minimumBudget: minimumBudget ?? this.minimumBudget,
      deadline: deadline ?? this.deadline,
      skills: skills ?? this.skills,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      isAccepted: isAccepted ?? this.isAccepted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
