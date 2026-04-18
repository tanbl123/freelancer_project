enum JobCategory {
  design,
  development,
  writing,
  marketing,
  video,
  audio,
  business,
  dataEntry,
  legal,
  other;

  static JobCategory fromString(String v) => JobCategory.values.firstWhere(
        (e) => e.name == v,
        orElse: () => JobCategory.other,
      );

  String get displayName {
    switch (this) {
      case JobCategory.design:
        return 'Design';
      case JobCategory.development:
        return 'Development';
      case JobCategory.writing:
        return 'Writing';
      case JobCategory.marketing:
        return 'Marketing';
      case JobCategory.video:
        return 'Video & Animation';
      case JobCategory.audio:
        return 'Audio';
      case JobCategory.business:
        return 'Business';
      case JobCategory.dataEntry:
        return 'Data Entry';
      case JobCategory.legal:
        return 'Legal';
      case JobCategory.other:
        return 'Other';
    }
  }
}
