import '../../../shared/enums/request_status.dart';

class FreelancerRequest {
  const FreelancerRequest({
    required this.id,
    required this.requesterId,
    required this.status,
    this.requestMessage,
    this.portfolioUrl,
    this.adminNote,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String requesterId;
  final RequestStatus status;
  final String? requestMessage;
  final String? portfolioUrl;
  final String? adminNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FreelancerRequest.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic v) {
      if (v == null) return null;
      return parseDate(v);
    }

    return FreelancerRequest(
      id: map['id'] as String,
      requesterId: map['requester_id'] as String,
      status: RequestStatus.fromString(map['status'] as String? ?? 'pending'),
      requestMessage: map['request_message'] as String?,
      portfolioUrl: map['portfolio_url'] as String?,
      adminNote: map['admin_note'] as String?,
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
      'requester_id': requesterId,
      'status': status.name,
      'request_message': requestMessage,
      'portfolio_url': portfolioUrl,
      'admin_note': adminNote,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': now,
    };
  }

  FreelancerRequest copyWith({
    RequestStatus? status,
    String? adminNote,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return FreelancerRequest(
      id: id,
      requesterId: requesterId,
      status: status ?? this.status,
      requestMessage: requestMessage,
      portfolioUrl: portfolioUrl,
      adminNote: adminNote ?? this.adminNote,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
