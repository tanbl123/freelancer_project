import '../../../shared/enums/dispute_reason.dart';
import '../../../shared/enums/dispute_resolution.dart';
import '../../../shared/enums/dispute_status.dart';

/// A formal dispute record raised by a client or freelancer.
///
/// Lifecycle:
/// 1. Created with [DisputeStatus.open] when a party calls [DisputeService.raiseDispute].
/// 2. Admin changes to [DisputeStatus.underReview] while investigating.
/// 3. Admin picks a [DisputeResolution], payment is adjusted, status → [DisputeStatus.resolved].
/// 4. Automatically transitions to [DisputeStatus.closed] once payment processing confirms.
///
/// Evidence is stored as a list of URLs (links to Drive, Dropbox, images, etc.)
/// — no file upload required on the Flutter side.
class DisputeRecord {
  const DisputeRecord({
    required this.id,
    required this.projectId,
    required this.raisedById,
    required this.clientId,
    required this.freelancerId,
    required this.status,
    required this.reason,
    required this.description,
    this.evidenceUrls = const [],
    this.adminNotes,
    this.resolution,
    this.clientRefundAmount,
    this.freelancerReleaseAmount,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID primary key.
  final String id;

  /// Project this dispute belongs to.
  final String projectId;

  /// UID of the user who raised the dispute (client or freelancer).
  final String raisedById;

  final String clientId;
  final String freelancerId;

  final DisputeStatus status;
  final DisputeReason reason;

  /// Free-text explanation from the party raising the dispute.
  final String description;

  /// Zero or more evidence links (URLs to documents, screenshots, etc.).
  final List<String> evidenceUrls;

  /// Internal admin notes — not visible to the parties.
  final String? adminNotes;

  /// Admin's chosen resolution strategy.
  final DisputeResolution? resolution;

  /// Amount (in RM) refunded to the client from remaining escrow.
  /// Null until admin processes a [partialSplit] or [fullRefundToClient].
  final double? clientRefundAmount;

  /// Gross amount (before platform fee) released to the freelancer.
  /// Null until admin processes a [partialSplit] or [fullReleaseToFreelancer].
  final double? freelancerReleaseAmount;

  /// UID of the admin who reviewed this dispute.
  final String? reviewedBy;

  /// When the admin made their decision.
  final DateTime? reviewedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  bool get isRaisedByClient => raisedById == clientId;
  bool get isRaisedByFreelancer => raisedById == freelancerId;
  bool get isResolved => status.isTerminal;
  bool get hasEvidence => evidenceUrls.isNotEmpty;

  // ── Supabase serialisation ─────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'project_id': projectId,
        'raised_by_id': raisedById,
        'client_id': clientId,
        'freelancer_id': freelancerId,
        'status': status.name,
        'reason': reason.name,
        'description': description,
        'evidence_urls': evidenceUrls,
        'admin_notes': adminNotes,
        'resolution': resolution?.name,
        'client_refund_amount': clientRefundAmount,
        'freelancer_release_amount': freelancerReleaseAmount,
        'reviewed_by': reviewedBy,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory DisputeRecord.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullable(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    List<String> parseUrls(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return DisputeRecord(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      raisedById: map['raised_by_id'] as String,
      clientId: map['client_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      status: DisputeStatus.fromString(
          map['status'] as String? ?? 'open'),
      reason: DisputeReason.fromString(
          map['reason'] as String? ?? 'other'),
      description: map['description'] as String? ?? '',
      evidenceUrls: parseUrls(map['evidence_urls']),
      adminNotes: map['admin_notes'] as String?,
      resolution: map['resolution'] == null
          ? null
          : DisputeResolution.fromString(map['resolution'] as String),
      clientRefundAmount: map['client_refund_amount'] == null
          ? null
          : (map['client_refund_amount'] as num).toDouble(),
      freelancerReleaseAmount: map['freelancer_release_amount'] == null
          ? null
          : (map['freelancer_release_amount'] as num).toDouble(),
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: parseNullable(map['reviewed_at']),
      createdAt: parse(map['created_at']),
      updatedAt: parse(map['updated_at']),
    );
  }

  DisputeRecord copyWith({
    DisputeStatus? status,
    String? adminNotes,
    DisputeResolution? resolution,
    double? clientRefundAmount,
    double? freelancerReleaseAmount,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) =>
      DisputeRecord(
        id: id,
        projectId: projectId,
        raisedById: raisedById,
        clientId: clientId,
        freelancerId: freelancerId,
        status: status ?? this.status,
        reason: reason,
        description: description,
        evidenceUrls: evidenceUrls,
        adminNotes: adminNotes ?? this.adminNotes,
        resolution: resolution ?? this.resolution,
        clientRefundAmount:
            clientRefundAmount ?? this.clientRefundAmount,
        freelancerReleaseAmount:
            freelancerReleaseAmount ?? this.freelancerReleaseAmount,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
