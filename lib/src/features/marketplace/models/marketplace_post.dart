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

  // ── Supabase map (ISO 8601, native arrays, native bool) ──────────────────────
  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'title': title,
      'description': description,
      'minimum_budget': minimumBudget,
      'deadline': deadline.toIso8601String(),
      'skills': skills,
      'type': type.name,
      'image_url': imageUrl,
      'is_accepted': isAccepted,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  // ── SQLite map (epoch ms, JSON-encoded lists) ────────────────────────────────
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

  // ── Dual-format fromMap ──────────────────────────────────────────────────────
  factory MarketplacePost.fromMap(Map<String, dynamic> map) {
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

    List<String> parseList(dynamic v) {
      if (v == null) return [];
      if (v is List) return List<String>.from(v);
      if (v is String && v.isNotEmpty) {
        try {
          return List<String>.from(jsonDecode(v) as List);
        } catch (_) {}
      }
      return [];
    }

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is int) return v == 1;
      return false;
    }

    return MarketplacePost(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      ownerName: map['owner_name'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      minimumBudget: (map['minimum_budget'] as num).toDouble(),
      deadline: parseDate(map['deadline']),
      skills: parseList(map['skills']),
      type: PostType.values.byName(map['type'] as String? ?? 'jobRequest'),
      imageUrl: map['image_url'] as String?,
      isAccepted: parseBool(map['is_accepted']),
      createdAt: parseDateNullable(map['created_at']),
      updatedAt: parseDateNullable(map['updated_at']),
    );
  }

  MarketplacePost copyWith({
    String? ownerName,
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
      ownerName: ownerName ?? this.ownerName,
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
