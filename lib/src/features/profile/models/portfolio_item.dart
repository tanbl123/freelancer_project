/// A single portfolio item on a freelancer's profile.
///
/// Represents a past project or piece of work the freelancer wants to
/// showcase. Stored in the `portfolio_items` Supabase table.
class PortfolioItem {
  const PortfolioItem({
    required this.id,
    required this.freelancerId,
    required this.title,
    this.description,
    this.imageUrl,
    this.projectDate,
    this.skills = const [],
    this.createdAt,
  });

  final String id;
  final String freelancerId;
  final String title;
  final String? description;

  /// Remote HTTPS URL (Supabase Storage) or null if no image uploaded.
  final String? imageUrl;

  /// Human-readable date string e.g. "Jan 2025". Free-form text.
  final String? projectDate;

  final List<String> skills;
  final DateTime? createdAt;

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'freelancer_id': freelancerId,
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'project_date': projectDate,
        'skills': skills,
        'created_at': createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
      };

  factory PortfolioItem.fromMap(Map<String, dynamic> map) => PortfolioItem(
        id: map['id'] as String,
        freelancerId: map['freelancer_id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        imageUrl: map['image_url'] as String?,
        projectDate: map['project_date'] as String?,
        skills: (map['skills'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString())
            : null,
      );

  PortfolioItem copyWith({
    String? title,
    String? description,
    String? imageUrl,
    String? projectDate,
    List<String>? skills,
  }) =>
      PortfolioItem(
        id: id,
        freelancerId: freelancerId,
        title: title ?? this.title,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        projectDate: projectDate ?? this.projectDate,
        skills: skills ?? this.skills,
        createdAt: createdAt,
      );
}
