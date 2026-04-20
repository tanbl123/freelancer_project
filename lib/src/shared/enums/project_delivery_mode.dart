/// How the freelancer delivers work on a project.
///
/// - [milestone] — multi-step delivery via a milestone plan (default).
/// - [single]    — one-shot delivery: freelancer submits once, client approves,
///                 full payment released, project completed.
enum ProjectDeliveryMode {
  milestone,
  single;

  static ProjectDeliveryMode fromString(String? v) =>
      v == 'single' ? single : milestone;

  String get displayName => switch (this) {
        ProjectDeliveryMode.milestone => 'Milestone Plan',
        ProjectDeliveryMode.single    => 'Single Delivery',
      };
}
