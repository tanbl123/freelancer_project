import 'dart:convert';

import '../../../shared/enums/job_status.dart';

/// Represents a job posting created by a Client.
/// Dual-serialization: toSupabaseMap() for cloud, toSqliteMap() for offline
/// SQLite cache. fromMap() accepts both formats automatically.
class JobPost {
  const JobPost({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.requiredSkills,
    this.budgetMin,
    this.budgetMax,
    this.deadline,
    this.projectDuration,
    this.coverImageUrl,
    this.allowPreEngagementChat = true,
    this.viewCount = 0,
    this.applicationCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String title;
  final String description;
  final String category;
  final JobStatus status;
  final List<String> requiredSkills;

  /// Budget lower bound (optional). Stored as NUMERIC in Supabase.
  final double? budgetMin;

  /// Budget upper bound (optional).
  final double? budgetMax;

  /// Optional application deadline.
  final DateTime? deadline;

  /// Optional project duration string (e.g. "2 Weeks"), used when the
  /// client sets a duration instead of a specific completion date.
  final String? projectDuration;

  /// Optional cover image (local path or remote URL).
  final String? coverImageUrl;

  /// Whether applicants may send a message before formally applying.
  final bool allowPreEngagementChat;

  /// Denormalized counters — updated server-side or via AppState.
  final int viewCount;
  final int applicationCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Computed helpers ──────────────────────────────────────────────────────

  bool get isExpired =>
      deadline != null && deadline!.isBefore(DateTime.now());

  /// A post is "live" only when status==open AND not expired.
  bool get isLive => status == JobStatus.open && !isExpired;

  /// Human-readable budget range string, or null if no budget set.
  String? get budgetDisplay {
    if (budgetMin == null && budgetMax == null) return null;
    String fmt(double v) => 'RM ${v.toStringAsFixed(0)}';
    if (budgetMin != null && budgetMax != null) {
      return '${fmt(budgetMin!)} – ${fmt(budgetMax!)}';
    }
    if (budgetMin != null) return 'From ${fmt(budgetMin!)}';
    return fmt(budgetMax!);
  }

  /// Remaining days until deadline, or null if no deadline set.
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  // ── Supabase serialization (ISO 8601 dates, native arrays) ────────────────

  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'title': title,
      'description': description,
      'category': category,
      'status': status.name,
      'required_skills': requiredSkills,
      if (budgetMin != null) 'budget_min': budgetMin,
      if (budgetMax != null) 'budget_max': budgetMax,
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
      if (projectDuration != null) 'project_duration': projectDuration,
      'cover_image_url': coverImageUrl,
      'allow_pre_engagement_chat': allowPreEngagementChat,
      'view_count': viewCount,
      'application_count': applicationCount,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  /// For inserting/updating — omits auto-managed counter columns.
  Map<String, dynamic> toSupabaseWriteMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'title': title,
      'description': description,
      'category': category,
      'status': status.name,
      'required_skills': requiredSkills,
      if (budgetMin != null) 'budget_min': budgetMin,
      if (budgetMax != null) 'budget_max': budgetMax,
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
      if (projectDuration != null) 'project_duration': projectDuration,
      'cover_image_url': coverImageUrl,
      'allow_pre_engagement_chat': allowPreEngagementChat,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  // ── SQLite serialization (epoch ms, JSON-encoded arrays) ─────────────────

  Map<String, dynamic> toSqliteMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'title': title,
      'description': description,
      'category': category,
      'status': status.name,
      'required_skills': jsonEncode(requiredSkills),
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'deadline': deadline?.millisecondsSinceEpoch,
      'project_duration': projectDuration,
      'cover_image_url': coverImageUrl,
      'allow_pre_engagement_chat': allowPreEngagementChat ? 1 : 0,
      'view_count': viewCount,
      'application_count': applicationCount,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  // ── Dual-format fromMap ───────────────────────────────────────────────────

  factory JobPost.fromMap(Map<String, dynamic> map) {
    DateTime? parseNullable(dynamic v) {
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
      return true;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      return (v as num).toDouble();
    }

    return JobPost(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      clientName: map['client_name'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String? ?? 'other',
      status: JobStatus.fromString(map['status'] as String? ?? 'open'),
      requiredSkills: parseList(map['required_skills']),
      budgetMin: parseDouble(map['budget_min']),
      budgetMax: parseDouble(map['budget_max']),
      deadline: parseNullable(map['deadline']),
      projectDuration: map['project_duration'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      allowPreEngagementChat: parseBool(map['allow_pre_engagement_chat']),
      viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
      applicationCount: (map['application_count'] as num?)?.toInt() ?? 0,
      createdAt: parseNullable(map['created_at']),
      updatedAt: parseNullable(map['updated_at']),
    );
  }

  // ── copyWith ─────────────────────────────────────────────────────────────

  JobPost copyWith({
    String? clientName,
    String? title,
    String? description,
    String? category,
    JobStatus? status,
    List<String>? requiredSkills,
    double? budgetMin,
    double? budgetMax,
    DateTime? deadline,
    String? projectDuration,
    String? coverImageUrl,
    bool? allowPreEngagementChat,
    int? viewCount,
    int? applicationCount,
  }) {
    return JobPost(
      id: id,
      clientId: clientId,
      clientName: clientName ?? this.clientName,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      deadline: deadline ?? this.deadline,
      projectDuration: projectDuration ?? this.projectDuration,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      allowPreEngagementChat:
          allowPreEngagementChat ?? this.allowPreEngagementChat,
      viewCount: viewCount ?? this.viewCount,
      applicationCount: applicationCount ?? this.applicationCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
