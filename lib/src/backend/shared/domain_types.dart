enum UserRole { client, freelancer }

enum PostType { jobRequest, serviceOffering }

enum ApplicationStatus { pending, accepted, rejected, withdrawn }

enum MilestoneStatus { draft, submitted, approved, locked }

enum OrderStatus { open, inProgress, completed, cancelled }

extension EnumNameX on Enum {
  String get dbValue => name;
}
