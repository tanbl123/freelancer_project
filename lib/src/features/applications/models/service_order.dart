import '../../../backend/shared/domain_types.dart';

/// Represents a client's request to a freelancer to fulfil a service listing.
///
/// Flow: client submits (pending) → freelancer accepts/rejects →
///       on acceptance a [ProjectItem] is created (convertedToProject).
class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.freelancerId,
    required this.freelancerName,
    required this.clientId,
    required this.clientName,
    required this.message,
    required this.status,
    this.proposedBudget,
    this.timelineDays,
    this.freelancerNote,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String serviceId;
  final String serviceTitle;
  final String freelancerId;
  final String freelancerName;
  final String clientId;
  final String clientName;

  /// The client's description of what they need done.
  final String message;

  final ServiceOrderStatus status;

  /// Optional budget the client is willing to pay.
  final double? proposedBudget;

  /// Optional expected timeline in days.
  final int? timelineDays;

  /// Freelancer's acceptance note or rejection reason.
  final String? freelancerNote;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  bool get isPending => status == ServiceOrderStatus.pending;
  bool get isAccepted => status == ServiceOrderStatus.accepted;

  // ── Supabase map (ISO 8601) ──────────────────────────────────────────────────
  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'service_id': serviceId,
      'service_title': serviceTitle,
      'freelancer_id': freelancerId,
      'freelancer_name': freelancerName,
      'client_id': clientId,
      'client_name': clientName,
      'message': message,
      'status': status.name,
      'proposed_budget': proposedBudget,
      'timeline_days': timelineDays,
      'freelancer_note': freelancerNote,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  // ── Dual-format fromMap ──────────────────────────────────────────────────────
  factory ServiceOrder.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ServiceOrder(
      id: map['id'] as String,
      serviceId: map['service_id'] as String,
      serviceTitle: map['service_title'] as String,
      freelancerId: map['freelancer_id'] as String,
      freelancerName: map['freelancer_name'] as String,
      clientId: map['client_id'] as String,
      clientName: map['client_name'] as String,
      message: map['message'] as String,
      status: ServiceOrderStatus.fromString(
          map['status'] as String? ?? 'pending'),
      proposedBudget: map['proposed_budget'] == null
          ? null
          : (map['proposed_budget'] as num).toDouble(),
      timelineDays: map['timeline_days'] == null
          ? null
          : (map['timeline_days'] as num).toInt(),
      freelancerNote: map['freelancer_note'] as String?,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  ServiceOrder copyWith({
    String? message,
    ServiceOrderStatus? status,
    double? proposedBudget,
    int? timelineDays,
    String? freelancerNote,
  }) {
    return ServiceOrder(
      id: id,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      freelancerId: freelancerId,
      freelancerName: freelancerName,
      clientId: clientId,
      clientName: clientName,
      message: message ?? this.message,
      status: status ?? this.status,
      proposedBudget: proposedBudget ?? this.proposedBudget,
      timelineDays: timelineDays ?? this.timelineDays,
      freelancerNote: freelancerNote ?? this.freelancerNote,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
