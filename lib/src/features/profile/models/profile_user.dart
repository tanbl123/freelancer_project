import 'dart:convert';

class ProfileUser {
  const ProfileUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.passwordHash,
    required this.phone,
    required this.role,
    this.bio,
    this.skills = const [],
    this.experience,
    this.resumeUrl,
    this.portfolioUrls = const [],
    this.photoUrl,
    this.averageRating,
    this.totalReviews,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String passwordHash;
  final String phone;
  final String role; // 'client' | 'freelancer'
  final String? bio;
  final List<String> skills;
  final String? experience;
  final String? resumeUrl;
  final List<String> portfolioUrls;
  final String? photoUrl;
  final double? averageRating;
  final int? totalReviews;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'uid': uid,
      'display_name': displayName,
      'email': email.toLowerCase(),
      'password_hash': passwordHash,
      'phone': phone,
      'role': role,
      'bio': bio,
      'skills': jsonEncode(skills),
      'experience': experience,
      'resume_url': resumeUrl,
      'portfolio_urls': jsonEncode(portfolioUrls),
      'photo_url': photoUrl,
      'average_rating': averageRating ?? 0.0,
      'total_reviews': totalReviews ?? 0,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  factory ProfileUser.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic v) {
      if (v == null || v == '') return [];
      try {
        return List<String>.from(jsonDecode(v as String));
      } catch (_) {
        return [];
      }
    }

    return ProfileUser(
      uid: map['uid'] as String,
      displayName: map['display_name'] as String,
      email: map['email'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: map['role'] as String? ?? 'freelancer',
      bio: map['bio'] as String?,
      skills: parseList(map['skills']),
      experience: map['experience'] as String?,
      resumeUrl: map['resume_url'] as String?,
      portfolioUrls: parseList(map['portfolio_urls']),
      photoUrl: map['photo_url'] as String?,
      averageRating: (map['average_rating'] as num?)?.toDouble(),
      totalReviews: map['total_reviews'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }

  ProfileUser copyWith({
    String? displayName,
    String? email,
    String? passwordHash,
    String? phone,
    String? role,
    String? bio,
    List<String>? skills,
    String? experience,
    String? resumeUrl,
    List<String>? portfolioUrls,
    String? photoUrl,
    double? averageRating,
    int? totalReviews,
  }) {
    return ProfileUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      experience: experience ?? this.experience,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      portfolioUrls: portfolioUrls ?? this.portfolioUrls,
      photoUrl: photoUrl ?? this.photoUrl,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
