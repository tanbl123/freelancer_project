class ProfileUser {
  const ProfileUser({
    required this.uid,
    required this.displayName,
    required this.role,
    this.bio,
    this.skills = const [],
    this.resumeUrl,
    this.portfolioUrls = const [],
    this.averageRating,
    this.totalReviews,
  });

  final String uid;
  final String displayName;
  final String role;
  final String? bio;
  final List<String> skills;
  final String? resumeUrl;
  final List<String> portfolioUrls;
  final double? averageRating;
  final int? totalReviews;
}
