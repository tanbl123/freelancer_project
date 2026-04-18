class SkillWithLevel {
  final String skill;
  final String level; // 'Beginner', 'Intermediate', 'Expert'

  const SkillWithLevel({required this.skill, required this.level});

  factory SkillWithLevel.fromMap(Map<String, dynamic> m) =>
      SkillWithLevel(skill: m['skill'] as String, level: m['level'] as String? ?? 'Beginner');

  Map<String, dynamic> toMap() => {'skill': skill, 'level': level};
}
