/// Status lifecycle for a [FreelancerService] listing.
enum ServiceStatus {
  /// Visible in the service feed; can be enquired / ordered.
  active,

  /// Hidden from the public feed; only the owner can see it.
  inactive,

  /// Soft-deleted; not visible anywhere in the UI.
  deleted;

  static ServiceStatus fromString(String v) => ServiceStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ServiceStatus.inactive,
      );

  String get displayName {
    switch (this) {
      case ServiceStatus.active:
        return 'Available';
      case ServiceStatus.inactive:
        return 'Paused';
      case ServiceStatus.deleted:
        return 'Removed';
    }
  }

  /// Whether the service appears publicly.
  bool get isVisible => this == ServiceStatus.active;
}
