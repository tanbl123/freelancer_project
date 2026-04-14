import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../features/applications/models/application_item.dart';
import '../features/marketplace/models/marketplace_post.dart';
import '../features/profile/models/profile_user.dart';
import '../features/ratings/models/review_item.dart';
import '../features/transactions/models/milestone_item.dart';
import '../features/transactions/models/project_item.dart';
import '../backend/shared/domain_types.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  late Database _db;

  Future<void> initialize() async {
    final dbPath = join(await getDatabasesPath(), 'freelancer_app.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        uid           TEXT PRIMARY KEY,
        display_name  TEXT NOT NULL,
        email         TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        phone         TEXT NOT NULL DEFAULT '',
        role          TEXT NOT NULL DEFAULT 'freelancer',
        bio           TEXT,
        skills        TEXT,
        experience    TEXT,
        resume_url    TEXT,
        portfolio_urls TEXT,
        photo_url     TEXT,
        average_rating REAL DEFAULT 0.0,
        total_reviews  INTEGER DEFAULT 0,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_users_email ON users(email)');

    await db.execute('''
      CREATE TABLE posts (
        id             TEXT PRIMARY KEY,
        owner_id       TEXT NOT NULL,
        owner_name     TEXT NOT NULL,
        title          TEXT NOT NULL,
        description    TEXT NOT NULL,
        minimum_budget REAL NOT NULL DEFAULT 0,
        deadline       INTEGER NOT NULL,
        skills         TEXT,
        type           TEXT NOT NULL,
        image_url      TEXT,
        is_accepted    INTEGER NOT NULL DEFAULT 0,
        created_at     INTEGER NOT NULL,
        updated_at     INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE applications (
        id               TEXT PRIMARY KEY,
        job_id           TEXT NOT NULL,
        client_id        TEXT NOT NULL,
        freelancer_id    TEXT NOT NULL,
        freelancer_name  TEXT NOT NULL,
        proposal_message TEXT NOT NULL,
        expected_budget  REAL NOT NULL,
        timeline_days    INTEGER NOT NULL,
        status           TEXT NOT NULL DEFAULT 'pending',
        resume_url       TEXT,
        voice_pitch_url  TEXT,
        created_at       INTEGER NOT NULL,
        updated_at       INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_applications_unique ON applications(job_id, freelancer_id)');

    await db.execute('''
      CREATE TABLE projects (
        id             TEXT PRIMARY KEY,
        job_id         TEXT NOT NULL,
        application_id TEXT NOT NULL,
        client_id      TEXT NOT NULL,
        freelancer_id  TEXT NOT NULL,
        status         TEXT NOT NULL DEFAULT 'inProgress',
        created_at     INTEGER NOT NULL,
        updated_at     INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE milestones (
        id                   TEXT PRIMARY KEY,
        project_id           TEXT NOT NULL,
        title                TEXT NOT NULL,
        description          TEXT NOT NULL,
        deadline             INTEGER NOT NULL,
        payment_amount       REAL NOT NULL,
        status               TEXT NOT NULL DEFAULT 'draft',
        deliverable_url      TEXT,
        client_signature_url TEXT,
        payment_token        TEXT,
        created_at           INTEGER NOT NULL,
        updated_at           INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reviews (
        id            TEXT PRIMARY KEY,
        project_id    TEXT NOT NULL,
        reviewer_id   TEXT NOT NULL,
        freelancer_id TEXT NOT NULL,
        stars         INTEGER NOT NULL,
        comment       TEXT NOT NULL,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_reviews_unique ON reviews(project_id, reviewer_id)');

    await db.execute('''
      CREATE TABLE cached_jobs (
        id        TEXT PRIMARY KEY,
        payload   TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<void> insertUser(ProfileUser user) async {
    await _db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ProfileUser?> getUserByEmail(String email) async {
    final rows = await _db.query('users',
        where: 'email = ?', whereArgs: [email.toLowerCase()]);
    if (rows.isEmpty) return null;
    return ProfileUser.fromMap(rows.first);
  }

  Future<ProfileUser?> getUserById(String uid) async {
    final rows = await _db.query('users', where: 'uid = ?', whereArgs: [uid]);
    if (rows.isEmpty) return null;
    return ProfileUser.fromMap(rows.first);
  }

  Future<List<ProfileUser>> getAllUsers() async {
    final rows = await _db.query('users');
    return rows.map(ProfileUser.fromMap).toList();
  }

  Future<void> updateUser(ProfileUser user) async {
    await _db.update('users', user.toMap(),
        where: 'uid = ?', whereArgs: [user.uid]);
  }

  // ── Posts ──────────────────────────────────────────────────────────────────

  Future<void> insertPost(MarketplacePost post) async {
    await _db.insert('posts', post.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns posts with deadline > now and is_accepted = 0.
  Future<List<MarketplacePost>> getActivePosts() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.query(
      'posts',
      where: 'deadline > ? AND is_accepted = 0',
      whereArgs: [now],
      orderBy: 'created_at DESC',
    );
    return rows.map(MarketplacePost.fromMap).toList();
  }

  Future<List<MarketplacePost>> getAllPosts() async {
    final rows = await _db.query('posts', orderBy: 'created_at DESC');
    return rows.map(MarketplacePost.fromMap).toList();
  }

  Future<MarketplacePost?> getPostById(String id) async {
    final rows = await _db.query('posts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return MarketplacePost.fromMap(rows.first);
  }

  Future<void> updatePost(MarketplacePost post) async {
    await _db.update('posts', post.toMap(),
        where: 'id = ?', whereArgs: [post.id]);
  }

  Future<void> deletePost(String id) async {
    await _db.delete('posts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markPostAccepted(String postId) async {
    await _db.update(
      'posts',
      {'is_accepted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  // ── Applications ───────────────────────────────────────────────────────────

  Future<void> insertApplication(ApplicationItem app) async {
    await _db.insert('applications', app.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ApplicationItem>> getApplicationsForJob(String jobId) async {
    final rows = await _db.query('applications',
        where: 'job_id = ?', whereArgs: [jobId], orderBy: 'created_at DESC');
    return rows.map(ApplicationItem.fromMap).toList();
  }

  Future<List<ApplicationItem>> getApplicationsByFreelancer(
      String freelancerId) async {
    final rows = await _db.query('applications',
        where: 'freelancer_id = ?',
        whereArgs: [freelancerId],
        orderBy: 'created_at DESC');
    return rows.map(ApplicationItem.fromMap).toList();
  }

  Future<List<ApplicationItem>> getApplicationsForClientJobs(
      String clientId) async {
    final rows = await _db.query('applications',
        where: 'client_id = ?',
        whereArgs: [clientId],
        orderBy: 'created_at DESC');
    return rows.map(ApplicationItem.fromMap).toList();
  }

  Future<List<ApplicationItem>> getAllApplications() async {
    final rows =
        await _db.query('applications', orderBy: 'created_at DESC');
    return rows.map(ApplicationItem.fromMap).toList();
  }

  Future<ApplicationItem?> getApplicationById(String id) async {
    final rows =
        await _db.query('applications', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ApplicationItem.fromMap(rows.first);
  }

  Future<bool> hasApplied(String jobId, String freelancerId) async {
    final rows = await _db.query('applications',
        where: 'job_id = ? AND freelancer_id = ?',
        whereArgs: [jobId, freelancerId]);
    return rows.isNotEmpty;
  }

  Future<void> updateApplicationStatus(
      String id, ApplicationStatus status) async {
    await _db.update(
      'applications',
      {
        'status': status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> rejectAllOtherApplications(
      String jobId, String keepId) async {
    await _db.update(
      'applications',
      {
        'status': ApplicationStatus.rejected.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch
      },
      where: 'job_id = ? AND id != ? AND status = ?',
      whereArgs: [jobId, keepId, ApplicationStatus.pending.name],
    );
  }

  Future<void> updateApplication(ApplicationItem app) async {
    await _db.update('applications', app.toMap(),
        where: 'id = ?', whereArgs: [app.id]);
  }

  // ── Projects ───────────────────────────────────────────────────────────────

  Future<void> insertProject(ProjectItem project) async {
    await _db.insert('projects', project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ProjectItem>> getProjectsForUser(String userId) async {
    final rows = await _db.query(
      'projects',
      where: 'client_id = ? OR freelancer_id = ?',
      whereArgs: [userId, userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ProjectItem.fromMap).toList();
  }

  Future<ProjectItem?> getProjectById(String id) async {
    final rows =
        await _db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ProjectItem.fromMap(rows.first);
  }

  Future<void> updateProjectStatus(String id, String status) async {
    await _db.update(
      'projects',
      {'status': status, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Milestones ─────────────────────────────────────────────────────────────

  Future<void> insertMilestone(MilestoneItem milestone) async {
    await _db.insert('milestones', milestone.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MilestoneItem>> getMilestonesForProject(
      String projectId) async {
    final rows = await _db.query('milestones',
        where: 'project_id = ?',
        whereArgs: [projectId],
        orderBy: 'created_at ASC');
    return rows.map(MilestoneItem.fromMap).toList();
  }

  Future<MilestoneItem?> getMilestoneById(String id) async {
    final rows =
        await _db.query('milestones', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return MilestoneItem.fromMap(rows.first);
  }

  Future<void> updateMilestone(MilestoneItem milestone) async {
    await _db.update('milestones', milestone.toMap(),
        where: 'id = ?', whereArgs: [milestone.id]);
  }

  Future<void> deleteMilestone(String id) async {
    await _db.delete('milestones', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> approveMilestone(
      String id, String signaturePath, String paymentToken) async {
    await _db.update(
      'milestones',
      {
        'status': MilestoneStatus.approved.name,
        'client_signature_url': signaturePath,
        'payment_token': paymentToken,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMilestoneStatus(String id, MilestoneStatus status) async {
    await _db.update(
      'milestones',
      {
        'status': status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Reviews ────────────────────────────────────────────────────────────────

  Future<void> insertReview(ReviewItem review) async {
    await _db.insert('reviews', review.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReviewItem>> getReviewsForFreelancer(
      String freelancerId) async {
    final rows = await _db.query('reviews',
        where: 'freelancer_id = ?',
        whereArgs: [freelancerId],
        orderBy: 'created_at DESC');
    return rows.map(ReviewItem.fromMap).toList();
  }

  Future<List<ReviewItem>> getAllReviews() async {
    final rows = await _db.query('reviews', orderBy: 'created_at DESC');
    return rows.map(ReviewItem.fromMap).toList();
  }

  Future<bool> hasReviewedProject(
      String projectId, String reviewerId) async {
    final rows = await _db.query('reviews',
        where: 'project_id = ? AND reviewer_id = ?',
        whereArgs: [projectId, reviewerId]);
    return rows.isNotEmpty;
  }

  Future<void> updateFreelancerRatingStats(String freelancerId) async {
    final reviews = await getReviewsForFreelancer(freelancerId);
    if (reviews.isEmpty) return;
    final avg = reviews.map((r) => r.stars).reduce((a, b) => a + b) /
        reviews.length;
    await _db.update(
      'users',
      {
        'average_rating': avg,
        'total_reviews': reviews.length,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'uid = ?',
      whereArgs: [freelancerId],
    );
  }

  Future<void> updateReview(ReviewItem review) async {
    await _db.update('reviews', review.toMap(),
        where: 'id = ?', whereArgs: [review.id]);
  }

  Future<void> deleteReview(String id) async {
    await _db.delete('reviews', where: 'id = ?', whereArgs: [id]);
  }

  // ── Milestone earnings (for charts) ────────────────────────────────────────

  /// Returns map of 'YYYY-MM' -> total earnings for the given freelancer.
  Future<Map<String, double>> getMonthlyEarnings(String freelancerId) async {
    // Get all projects for this freelancer
    final projects = await getProjectsForUser(freelancerId);
    final freelancerProjects =
        projects.where((p) => p.freelancerId == freelancerId).toList();

    final result = <String, double>{};
    for (final project in freelancerProjects) {
      final milestones = await getMilestonesForProject(project.id);
      for (final ms in milestones) {
        if (ms.status == MilestoneStatus.approved ||
            ms.status == MilestoneStatus.locked) {
          final dt = DateTime.fromMillisecondsSinceEpoch(
              ms.updatedAt?.millisecondsSinceEpoch ??
                  ms.createdAt?.millisecondsSinceEpoch ??
                  0);
          final key =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
          result[key] = (result[key] ?? 0) + ms.paymentAmount;
        }
      }
    }
    return result;
  }

  /// Returns map of stars (1-5) -> count for the given freelancer.
  Future<Map<int, int>> getRatingDistribution(String freelancerId) async {
    final reviews = await getReviewsForFreelancer(freelancerId);
    final result = <int, int>{};
    for (final r in reviews) {
      result[r.stars] = (result[r.stars] ?? 0) + 1;
    }
    return result;
  }

  // ── Offline job cache ──────────────────────────────────────────────────────

  Future<void> cacheJobs(List<MarketplacePost> posts) async {
    final batch = _db.batch();
    batch.delete('cached_jobs');
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final post in posts.take(20)) {
      batch.insert('cached_jobs', {
        'id': post.id,
        'payload': jsonEncode(post.toMap()),
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<MarketplacePost>> getCachedJobs() async {
    final rows = await _db.query('cached_jobs', orderBy: 'cached_at DESC');
    return rows
        .map((r) => MarketplacePost.fromMap(
            jsonDecode(r['payload'] as String) as Map<String, dynamic>))
        .toList();
  }

  // ── Completed project check (for reviews) ─────────────────────────────────

  Future<ProjectItem?> getCompletedProjectBetween(
      String clientId, String freelancerId) async {
    final rows = await _db.query(
      'projects',
      where:
          'client_id = ? AND freelancer_id = ? AND status = ?',
      whereArgs: [clientId, freelancerId, 'completed'],
    );
    if (rows.isEmpty) return null;
    return ProjectItem.fromMap(rows.first);
  }
}
