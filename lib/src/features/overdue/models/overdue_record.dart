import '../../../shared/enums/overdue_status.dart';

/// Persisted record tracking the overdue-warning pipeline for a single
/// active milestone.
///
/// One record per (project, milestone) pair. When the milestone is completed
/// before enforcement the record is marked [autoResolved] = true.
/// When enforcement fires, [triggeredAt] is set and the record is final.
class OverdueRecord {
  const OverdueRecord({
    required this.id,
    required this.projectId,
    required this.milestoneId,
    required this.freelancerId,
    required this.clientId,
    required this.status,
    required this.milestoneDeadline,
    this.warningFirstSentAt,
    this.warningSecondSentAt,
    this.finalWarningAt,
    this.triggeredAt,
    this.autoResolved = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String milestoneId;
  final String freelancerId;
  final String clientId;

  /// Current stage in the warning pipeline.
  final OverdueStatus status;

  /// The milestone's effective deadline (including any approved extension).
  final DateTime milestoneDeadline;

  /// When the 3-day warning notification was sent (null = not yet sent).
  final DateTime? warningFirstSentAt;

  /// When the 1-day warning notification was sent (null = not yet sent).
  final DateTime? warningSecondSentAt;

  /// When the final-warning notification was sent (null = not yet sent).
  final DateTime? finalWarningAt;

  /// When auto-enforcement was applied (null = not yet triggered).
  final DateTime? triggeredAt;

  /// True when the milestone was completed before enforcement fired.
  final bool autoResolved;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  bool get isEnforced => triggeredAt != null;
  bool get isResolved => autoResolved || isEnforced;

  // ── Supabase serialisation ─────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'project_id': projectId,
      'milestone_id': milestoneId,
      'freelancer_id': freelancerId,
      'client_id': clientId,
      'status': status.name,
      'milestone_deadline': milestoneDeadline.toIso8601String(),
      'warning_first_sent_at': warningFirstSentAt?.toIso8601String(),
      'warning_second_sent_at': warningSecondSentAt?.toIso8601String(),
      'final_warning_at': finalWarningAt?.toIso8601String(),
      'triggered_at': triggeredAt?.toIso8601String(),
      'auto_resolved': autoResolved,
      'created_at': createdAt.toIso8601String(),
      'updated_at': now,
    };
  }

  factory OverdueRecord.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullable(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return OverdueRecord(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      milestoneId: map['milestone_id'] as String,
      freelancerId: map['freelancer_id'] as String,
      clientId: map['client_id'] as String,
      status: OverdueStatus.fromString(map['status'] as String? ?? 'onTrack'),
      milestoneDeadline: parse(map['milestone_deadline']),
      warningFirstSentAt: parseNullable(map['warning_first_sent_at']),
      warningSecondSentAt: parseNullable(map['warning_second_sent_at']),
      finalWarningAt: parseNullable(map['final_warning_at']),
      triggeredAt: parseNullable(map['triggered_at']),
      autoResolved: map['auto_resolved'] == true || map['auto_resolved'] == 1,
      createdAt: parse(map['created_at']),
      updatedAt: parse(map['updated_at']),
    );
  }

  OverdueRecord copyWith({
    OverdueStatus? status,
    DateTime? milestoneDeadline,
    DateTime? warningFirstSentAt,
    DateTime? warningSecondSentAt,
    DateTime? finalWarningAt,
    DateTime? triggeredAt,
    bool? autoResolved,
  }) {
    return OverdueRecord(
      id: id,
      projectId: projectId,
      milestoneId: milestoneId,
      freelancerId: freelancerId,
      clientId: clientId,
      status: status ?? this.status,
      milestoneDeadline: milestoneDeadline ?? this.milestoneDeadline,
      warningFirstSentAt: warningFirstSentAt ?? this.warningFirstSentAt,
      warningSecondSentAt: warningSecondSentAt ?? this.warningSecondSentAt,
      finalWarningAt: finalWarningAt ?? this.finalWarningAt,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      autoResolved: autoResolved ?? this.autoResolved,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
