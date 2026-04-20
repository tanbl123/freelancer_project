// Re-export shared enums so all existing code keeps working via this import.
export '../../shared/enums/user_role.dart';
export '../../shared/enums/account_status.dart';
export '../../shared/enums/request_status.dart';
export '../../shared/enums/appeal_status.dart';
export '../../shared/enums/job_status.dart';
export '../../shared/enums/job_category.dart';
export '../../shared/enums/service_status.dart';
export '../../shared/enums/service_order_status.dart';
export '../../shared/enums/project_status.dart';
export '../../shared/enums/milestone_status.dart';
export '../../shared/enums/payment_status.dart';
export '../../shared/enums/payout_status.dart';
export '../../shared/enums/overdue_status.dart';
export '../../shared/enums/notification_type.dart';
export '../../shared/enums/dispute_status.dart';
export '../../shared/enums/dispute_reason.dart';
export '../../shared/enums/dispute_resolution.dart';
export '../../shared/enums/chat_room_type.dart';
export '../../shared/enums/message_type.dart';
export '../../shared/enums/review_status.dart';
export '../../shared/enums/project_delivery_mode.dart';

// ── Legacy enums kept here (other modules depend on these) ────────────────────
//
// PostType — used by MarketplacePost to distinguish job-request posts from
//   service-offering posts.
//
// ApplicationStatus — used by ApplicationItem (job applications, not service
//   orders). Service orders use ServiceOrderStatus from the shared enums above.
//
// Note: OrderStatus was removed — it was never referenced anywhere in the
// codebase. ServiceOrderStatus (shared/enums/service_order_status.dart) is
// the canonical enum for order lifecycle transitions.

enum PostType { jobRequest, serviceOffering }

enum ApplicationStatus { pending, accepted, rejected, withdrawn, convertedToProject }

/// Global convenience extension: every [Enum] exposes a [dbValue] getter that
/// defaults to [Enum.name].
///
/// **Exception — [AppealStatus]:**  its `underReview` value overrides [dbValue]
/// to return `'under_review'` (snake_case) to match the SQL CHECK constraint.
/// Always call `.dbValue` instead of `.name` when persisting any enum to the
/// database to handle that special case correctly.
extension EnumNameX on Enum {
  String get dbValue => name;
}
