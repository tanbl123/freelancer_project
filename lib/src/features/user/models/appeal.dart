import '../../../shared/enums/appeal_status.dart';

class Appeal {
  const Appeal({
    required this.id,
    required this.appellantId,
    required this.reason,
    this.evidenceUrls = const [],
    required this.status,
    this.adminResponse,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String appellantId;
  final String reason;
  final List<String> evidenceUrls;
  final AppealStatus status;
  final String? adminResponse;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Appeal.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic v) {
      if (v == null) return null;
      return parseDate(v);
    }

    List<String> parseList(dynamic v) {
      if (v is List) return List<String>.from(v);
      return [];
    }

    return Appeal(
      id: map['id'] as String,
      appellantId: map['appellant_id'] as String,
      reason: map['reason'] as String,
      evidenceUrls: parseList(map['evidence_urls']),
      status: AppealStatus.fromString(map['status'] as String? ?? 'open'),
      adminResponse: map['admin_response'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: parseDateNullable(map['reviewed_at']),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'appellant_id': appellantId,
      'reason': reason,
      'evidence_urls': evidenceUrls,
      'status': status.dbValue,
      'admin_response': adminResponse,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': now,
    };
  }

  Appeal copyWith({
    AppealStatus? status,
    String? adminResponse,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return Appeal(
      id: id,
      appellantId: appellantId,
      reason: reason,
      evidenceUrls: evidenceUrls,
      status: status ?? this.status,
      adminResponse: adminResponse ?? this.adminResponse,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
