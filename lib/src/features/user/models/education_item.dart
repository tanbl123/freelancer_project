class EducationItem {
  final String country;
  final String school;
  final String? degree; // Bachelor's, Master's, PhD, Diploma, etc.
  final String? fieldOfStudy;
  final int? yearOfGraduation;

  const EducationItem({
    required this.country,
    required this.school,
    this.degree,
    this.fieldOfStudy,
    this.yearOfGraduation,
  });

  factory EducationItem.fromMap(Map<String, dynamic> m) => EducationItem(
        country: m['country'] as String,
        school: m['school'] as String,
        degree: m['degree'] as String?,
        fieldOfStudy: m['fieldOfStudy'] as String?,
        yearOfGraduation: (m['yearOfGraduation'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'country': country,
        'school': school,
        'degree': degree,
        'fieldOfStudy': fieldOfStudy,
        'yearOfGraduation': yearOfGraduation,
      };
}
