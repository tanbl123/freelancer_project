import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/shared/domain_types.dart';
import '../features/applications/models/application_item.dart';
import '../features/marketplace/models/marketplace_post.dart';
import '../features/profile/models/profile_user.dart';
import '../features/ratings/models/review_item.dart';
import '../features/transactions/models/milestone_item.dart';
import '../features/transactions/models/project_item.dart';

/// Drop-in replacement for DatabaseService.
/// Uses Supabase (PostgreSQL) for all cloud data.
/// SQLite is kept ONLY for the offline job cache (Module 1 requirement).
class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  late Database _localDb;

  SupabaseClient get _client => Supabase.instance.client;

  // ── Initialization (local SQLite cache only) ───────────────────────────────

  Future<void> initialize() async {
    // Windows / Linux / macOS need the FFI factory — sqflite only works
    // natively on Android and iOS.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = join(await getDatabasesPath(), 'freelancer_cache.db');
    _localDb = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_jobs (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ── Users (Supabase profiles table) ───────────────────────────────────────

  Future<void> insertUser(ProfileUser user) async {
    await _client.from('profiles').insert(user.toSupabaseMap());
  }

  Future<ProfileUser?> getUserByEmail(String email) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();
    return row == null ? null : ProfileUser.fromMap(row);
  }

  Future<ProfileUser?> getUserById(String uid) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('uid', uid)
        .maybeSingle();
    return row == null ? null : ProfileUser.fromMap(row);
  }

  Future<List<ProfileUser>> getAllUsers() async {
    final rows = await _client.from('profiles').select();
    return rows.map(ProfileUser.fromMap).toList();
  }

  Future<void> updateUser(ProfileUser user) async {
    await _client
        .from('profiles')
        .update(user.toSupabaseMap())
        .eq('uid', user.uid);
  }

  // ── Posts ──────────────────────────────────────────────────────────────────

  Future<void> insertPost(MarketplacePost post) async {
    await _client.from('posts').insert(post.toSupabaseMap());
  }

  Future<List<MarketplacePost>> getActivePosts() async {
    final rows = await _client
        .from('posts')
        .select()
        .eq('is_accepted', false)
        .gt('deadline', DateTime.now().toIso8601String())
        .order('created_at', ascending: false);
    return rows.map(MarketplacePost.fromMap).toList();
  }

  Future<List<MarketplacePost>> getAllPosts() async {
    final rows = await _client
        .from('posts')
        .select()
        .order('created_at', ascending: false);
    return rows.map(MarketplacePost.fromMap).toList();
  }

  Future<MarketplacePost?> getPostById(String id) async {
    final row = await _client
        .from('posts')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : MarketplacePost.fromMap(row);
  }

  Future<void> updatePost(MarketplacePost post) async {
    await _client
        .from('posts')
        .update(post.toSupabaseMap())
        .eq('id', post.id);
  }

  Future<void> deletePost(String id) async {
    await _client.from('posts').delete().eq('id', id);
  }

  Future<void> markPostAccepted(String jobId) async {
    await _client.from('posts').update({
      'is_accepted': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  // ── Applications ───────────────────────────────────────────────────────────

  Future<void> insertApplication(ApplicationItem app) async {
    await _client.from('applications').insert(app.toSupabaseMap());
  }

  Future<List<ApplicationItem>> getAllApplications() async {
    final rows = await _client
        .from('applications')
        .select()
        .order('created_at', ascending: false);
    return rows.map(ApplicationItem.fromMap).toList();
  }

  Future<bool> hasApplied(String jobId, String freelancerId) async {
    final rows = await _client
        .from('applications')
        .select('id')
        .eq('job_id', jobId)
        .eq('freelancer_id', freelancerId);
    return rows.isNotEmpty;
  }

  Future<void> updateApplicationStatus(
      String appId, ApplicationStatus status) async {
    await _client.from('applications').update({
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', appId);
  }

  Future<void> rejectAllOtherApplications(
      String jobId, String winnerAppId) async {
    await _client.from('applications').update({
      'status': ApplicationStatus.rejected.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('job_id', jobId).neq('id', winnerAppId).eq('status', 'pending');
  }

  Future<void> updateApplication(ApplicationItem app) async {
    await _client
        .from('applications')
        .update(app.toSupabaseMap())
        .eq('id', app.id);
  }

  // ── Projects ───────────────────────────────────────────────────────────────

  Future<void> insertProject(ProjectItem project) async {
    await _client.from('projects').insert(project.toSupabaseMap());
  }

  Future<List<ProjectItem>> getProjectsForUser(String uid) async {
    final rows = await _client
        .from('projects')
        .select()
        .or('client_id.eq.$uid,freelancer_id.eq.$uid')
        .order('created_at', ascending: false);
    return rows.map(ProjectItem.fromMap).toList();
  }

  Future<ProjectItem?> getProjectById(String id) async {
    final row = await _client
        .from('projects')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ProjectItem.fromMap(row);
  }

  Future<void> updateProjectStatus(String projectId, String status) async {
    await _client.from('projects').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  // ── Milestones ─────────────────────────────────────────────────────────────

  Future<void> insertMilestone(MilestoneItem milestone) async {
    await _client.from('milestones').insert(milestone.toSupabaseMap());
  }

  Future<List<MilestoneItem>> getMilestonesForProject(
      String projectId) async {
    final rows = await _client
        .from('milestones')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: true);
    return rows.map(MilestoneItem.fromMap).toList();
  }

  Future<MilestoneItem?> getMilestoneById(String id) async {
    final row = await _client
        .from('milestones')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : MilestoneItem.fromMap(row);
  }

  Future<void> updateMilestone(MilestoneItem milestone) async {
    await _client
        .from('milestones')
        .update(milestone.toSupabaseMap())
        .eq('id', milestone.id);
  }

  Future<void> deleteMilestone(String id) async {
    await _client.from('milestones').delete().eq('id', id);
  }

  Future<void> approveMilestone(
      String id, String signaturePath, String paymentToken) async {
    await _client.from('milestones').update({
      'status': MilestoneStatus.approved.name,
      'client_signature_url': signaturePath,
      'payment_token': paymentToken,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> updateMilestoneStatus(
      String id, MilestoneStatus status) async {
    await _client.from('milestones').update({
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Reviews ────────────────────────────────────────────────────────────────

  Future<void> insertReview(ReviewItem review) async {
    await _client.from('reviews').insert(review.toSupabaseMap());
  }

  Future<List<ReviewItem>> getAllReviews() async {
    final rows = await _client
        .from('reviews')
        .select()
        .order('created_at', ascending: false);
    return rows.map(ReviewItem.fromMap).toList();
  }

  Future<bool> hasReviewedProject(
      String projectId, String reviewerId) async {
    final rows = await _client
        .from('reviews')
        .select('id')
        .eq('project_id', projectId)
        .eq('reviewer_id', reviewerId);
    return rows.isNotEmpty;
  }

  Future<void> updateFreelancerRatingStats(String freelancerId) async {
    final rows = await _client
        .from('reviews')
        .select('stars')
        .eq('freelancer_id', freelancerId);

    if (rows.isEmpty) {
      await _client.from('profiles').update({
        'average_rating': 0.0,
        'total_reviews': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('uid', freelancerId);
      return;
    }

    final total = rows.length;
    final sum = rows.fold<double>(
        0, (s, r) => s + (r['stars'] as num).toDouble());
    final avg = sum / total;

    await _client.from('profiles').update({
      'average_rating': avg,
      'total_reviews': total,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('uid', freelancerId);
  }

  Future<void> updateReview(ReviewItem review) async {
    await _client
        .from('reviews')
        .update(review.toSupabaseMap())
        .eq('id', review.id);
  }

  Future<void> deleteReview(String id) async {
    await _client.from('reviews').delete().eq('id', id);
  }

  // ── Analytics ──────────────────────────────────────────────────────────────

  Future<Map<String, double>> getMonthlyEarnings(
      String freelancerId) async {
    // Get all projects for this freelancer
    final projectRows = await _client
        .from('projects')
        .select('id')
        .eq('freelancer_id', freelancerId);

    if (projectRows.isEmpty) return {};

    final projectIds =
        projectRows.map((r) => r['id'] as String).toList();

    // Get approved/locked milestones for these projects
    final milestoneRows = await _client
        .from('milestones')
        .select('payment_amount,updated_at,status')
        .inFilter('project_id', projectIds)
        .or('status.eq.approved,status.eq.locked');

    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final Map<String, double> result = {};
    for (final row in milestoneRows) {
      final updatedAt = _parseDate(row['updated_at']);
      final key =
          '${monthNames[updatedAt.month - 1]} ${updatedAt.year}';
      result[key] =
          (result[key] ?? 0) + (row['payment_amount'] as num).toDouble();
    }
    return result;
  }

  Future<Map<int, int>> getRatingDistribution(
      String freelancerId) async {
    final rows = await _client
        .from('reviews')
        .select('stars')
        .eq('freelancer_id', freelancerId);

    final Map<int, int> result = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final row in rows) {
      final stars = (row['stars'] as num).toInt();
      result[stars] = (result[stars] ?? 0) + 1;
    }
    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<ProjectItem?> getCompletedProjectBetween(
      String userId1, String userId2) async {
    final rows = await _client
        .from('projects')
        .select()
        .or('client_id.eq.$userId1,freelancer_id.eq.$userId1')
        .eq('status', 'completed');

    final projects = rows.map(ProjectItem.fromMap).toList();
    return projects
        .where((p) =>
            (p.clientId == userId1 && p.freelancerId == userId2) ||
            (p.clientId == userId2 && p.freelancerId == userId1))
        .firstOrNull;
  }

  // ── Offline cache (SQLite only) ────────────────────────────────────────────

  Future<void> cacheJobs(List<MarketplacePost> posts) async {
    final batch = _localDb.batch();
    batch.delete('cached_jobs');
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final post in posts.take(20)) {
      batch.insert(
        'cached_jobs',
        {
          'id': post.id,
          'payload': jsonEncode(post.toMap()),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<MarketplacePost>> getCachedJobs() async {
    final rows = await _localDb.query(
      'cached_jobs',
      orderBy: 'cached_at DESC',
    );
    return rows.map((row) {
      final decoded =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return MarketplacePost.fromMap(decoded);
    }).toList();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  DateTime _parseDate(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}
