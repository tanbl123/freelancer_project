import 'dart:convert';

import '../../../shared/enums/account_status.dart';
import '../../../shared/enums/user_role.dart';
import '../../user/models/certification_item.dart';
import '../../user/models/education_item.dart';
import '../../user/models/skill_with_level.dart';
import '../../user/models/work_experience.dart';

class ProfileUser {
  const ProfileUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.passwordHash = '',
    required this.phone,
    required this.role,
    this.accountStatus = AccountStatus.active,
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
    this.skillsWithLevel = const [],
    this.workExperiences = const [],
    this.educations = const [],
    this.certifications = const [],
    this.portfolioDescription,
  });

  final String uid;
  final String displayName;
  final String email;
  final String passwordHash; // always empty string — Supabase Auth owns credentials
  final String phone;
  final UserRole role;
  final AccountStatus accountStatus;
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
  final List<SkillWithLevel> skillsWithLevel;
  final List<WorkExperience> workExperiences;
  final List<EducationItem> educations;
  final List<CertificationItem> certifications;
  final String? portfolioDescription;

  // Backward-compat: treat as active when accountStatus is not deactivated
  bool get isActive => accountStatus != AccountStatus.deactivated;

  // ── Supabase map (ISO 8601, native arrays) ───────────────────────────────────
  Map<String, dynamic> toSupabaseMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'uid': uid,
      'display_name': displayName,
      'email': email.toLowerCase(),
      'phone': phone,
      'role': role.name,
      'account_status': accountStatus.name,
      'bio': bio,
      'skills': skillsWithLevel.isNotEmpty
          ? skillsWithLevel.map((s) => s.skill).toList()
          : skills,
      'experience': experience,
      'resume_url': resumeUrl,
      'portfolio_urls': portfolioUrls,
      'photo_url': photoUrl,
      'average_rating': averageRating ?? 0.0,
      'total_reviews': totalReviews ?? 0,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': now,
      'skills_with_level': skillsWithLevel.map((s) => s.toMap()).toList(),
      'work_experiences': workExperiences.map((e) => e.toMap()).toList(),
      'educations': educations.map((e) => e.toMap()).toList(),
      'certifications': certifications.map((c) => c.toMap()).toList(),
      'portfolio_description': portfolioDescription,
    };
  }

  // ── SQLite map (epoch ms, JSON-encoded lists) ────────────────────────────────
  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'uid': uid,
      'display_name': displayName,
      'email': email.toLowerCase(),
      'password_hash': passwordHash,
      'phone': phone,
      'role': role.name,
      'account_status': accountStatus.name,
      'bio': bio,
      'skills': jsonEncode(skills),
      'experience': experience,
      'resume_url': resumeUrl,
      'portfolio_urls': jsonEncode(portfolioUrls),
      'photo_url': photoUrl,
      'average_rating': averageRating ?? 0.0,
      'total_reviews': totalReviews ?? 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch ?? now,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? now,
    };
  }

  // ── Dual-format fromMap (handles Supabase ISO 8601 and SQLite epoch int) ─────
  factory ProfileUser.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    List<String> parseList(dynamic v) {
      if (v == null) return [];
      if (v is List) return List<String>.from(v);
      if (v is String && v.isNotEmpty) {
        try {
          return List<String>.from(jsonDecode(v) as List);
        } catch (_) {}
      }
      return [];
    }

    List<T> parseJsonList<T>(
        dynamic v, T Function(Map<String, dynamic>) factory) {
      if (v == null) return [];
      if (v is List) {
        return v.map((e) => factory(e as Map<String, dynamic>)).toList();
      }
      if (v is String && v.isNotEmpty) {
        try {
          final decoded = jsonDecode(v) as List;
          return decoded
              .map((e) => factory(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      return [];
    }

    // Legacy rows may only have is_active bool; derive accountStatus from it.
    AccountStatus parseAccountStatus(dynamic raw, dynamic isActiveFallback) {
      if (raw != null && raw is String && raw.isNotEmpty) {
        return AccountStatus.fromString(raw);
      }
      // Fallback for rows that predate the account_status column
      final active = isActiveFallback is bool
          ? isActiveFallback
          : (isActiveFallback as int? ?? 1) == 1;
      return active ? AccountStatus.active : AccountStatus.deactivated;
    }

    return ProfileUser(
      uid: map['uid'] as String,
      displayName: map['display_name'] as String,
      email: map['email'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String? ?? 'client'),
      accountStatus:
          parseAccountStatus(map['account_status'], map['is_active']),
      bio: map['bio'] as String?,
      skills: parseList(map['skills']),
      experience: map['experience'] as String?,
      resumeUrl: map['resume_url'] as String?,
      portfolioUrls: parseList(map['portfolio_urls']),
      photoUrl: map['photo_url'] as String?,
      averageRating: (map['average_rating'] as num?)?.toDouble(),
      totalReviews: (map['total_reviews'] as num?)?.toInt(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      skillsWithLevel: parseJsonList(
          map['skills_with_level'], SkillWithLevel.fromMap),
      workExperiences: parseJsonList(
          map['work_experiences'], WorkExperience.fromMap),
      educations: parseJsonList(map['educations'], EducationItem.fromMap),
      certifications:
          parseJsonList(map['certifications'], CertificationItem.fromMap),
      portfolioDescription: map['portfolio_description'] as String?,
    );
  }

  ProfileUser copyWith({
    String? displayName,
    String? email,
    String? passwordHash,
    String? phone,
    UserRole? role,
    AccountStatus? accountStatus,
    String? bio,
    bool clearBio = false,
    List<String>? skills,
    String? experience,
    bool clearExperience = false,
    String? resumeUrl,
    bool clearResumeUrl = false,
    List<String>? portfolioUrls,
    String? photoUrl,
    bool clearPhotoUrl = false,
    double? averageRating,
    int? totalReviews,
    List<SkillWithLevel>? skillsWithLevel,
    List<WorkExperience>? workExperiences,
    List<EducationItem>? educations,
    List<CertificationItem>? certifications,
    String? portfolioDescription,
    bool clearPortfolioDescription = false,
  }) {
    return ProfileUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      bio: clearBio ? null : (bio ?? this.bio),
      skills: skills ?? this.skills,
      experience: clearExperience ? null : (experience ?? this.experience),
      resumeUrl: clearResumeUrl ? null : (resumeUrl ?? this.resumeUrl),
      portfolioUrls: portfolioUrls ?? this.portfolioUrls,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      skillsWithLevel: skillsWithLevel ?? this.skillsWithLevel,
      workExperiences: workExperiences ?? this.workExperiences,
      educations: educations ?? this.educations,
      certifications: certifications ?? this.certifications,
      portfolioDescription: clearPortfolioDescription
          ? null
          : (portfolioDescription ?? this.portfolioDescription),
    );
  }
}
