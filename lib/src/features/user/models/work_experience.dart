class WorkExperience {
  final String title;
  final String? employmentType; // Full-time, Part-time, Freelance, Contract, Internship
  final String company;
  final bool currentlyWorkHere;
  final String? startDate; // e.g. "Jan 2020"
  final String? endDate;
  final String? description; // max 2000 chars
  final String? industry;

  const WorkExperience({
    required this.title,
    this.employmentType,
    required this.company,
    this.currentlyWorkHere = false,
    this.startDate,
    this.endDate,
    this.description,
    this.industry,
  });

  factory WorkExperience.fromMap(Map<String, dynamic> m) => WorkExperience(
        title: m['title'] as String,
        employmentType: m['employmentType'] as String?,
        company: m['company'] as String,
        currentlyWorkHere: m['currentlyWorkHere'] as bool? ?? false,
        startDate: m['startDate'] as String?,
        endDate: m['endDate'] as String?,
        description: m['description'] as String?,
        industry: m['industry'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'employmentType': employmentType,
        'company': company,
        'currentlyWorkHere': currentlyWorkHere,
        'startDate': startDate,
        'endDate': endDate,
        'description': description,
        'industry': industry,
      };
}
