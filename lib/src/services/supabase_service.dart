import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/shared/domain_types.dart';
import '../shared/models/category_item.dart';
import '../features/applications/models/application_item.dart';
import '../features/applications/models/service_order.dart';
import '../features/jobs/local/job_cache_dao.dart';
import '../features/jobs/models/job_post.dart';
import '../features/marketplace/models/marketplace_post.dart';
import '../features/services/models/freelancer_service.dart';
import '../features/profile/models/profile_user.dart';
import '../features/profile/models/portfolio_item.dart';
import '../features/ratings/models/review_item.dart';
import '../features/transactions/models/milestone_item.dart';
import '../features/transactions/models/project_item.dart';
import '../features/user/models/appeal.dart';
import '../features/user/models/freelancer_request.dart';
import '../features/chat/models/chat_message.dart';
import '../features/chat/models/chat_room.dart';
import '../features/disputes/models/dispute_record.dart';
import '../features/notifications/models/in_app_notification.dart';
import '../features/overdue/models/overdue_record.dart';
import '../features/payment/models/payment_record.dart';
import '../features/payment/models/payout_record.dart';

/// Drop-in replacement for DatabaseService.
/// Uses Supabase (PostgreSQL) for all cloud data.
/// SQLite is kept ONLY for the offline job cache (Module 1 requirement).
class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  late Database     _localDb;
  late JobCacheDao  _jobCacheDao;

  SupabaseClient get _client => Supabase.instance.client;

  /// Exposed so [AppState] can read cache metadata (last-synced timestamp).
  JobCacheDao get jobCacheDao => _jobCacheDao;

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
      // v4: replaces blob-based cached_job_posts with columnar job_posts_cache
      //     + job_cache_meta for last-synced timestamp.
      version: 4,
      onCreate: (db, version) async {
        // ── Legacy tables (kept for backward compatibility) ──────────────────
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_jobs (
            id        TEXT    PRIMARY KEY,
            payload   TEXT    NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_job_posts (
            id        TEXT    PRIMARY KEY,
            payload   TEXT    NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_freelancer_services (
            id        TEXT    PRIMARY KEY,
            payload   TEXT    NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        // ── v4: columnar job cache + meta ────────────────────────────────────
        await JobCacheDao.ensureTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_job_posts (
              id TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              cached_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_freelancer_services (
              id TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              cached_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          // Add columnar job cache tables introduced in v4.
          await JobCacheDao.ensureTables(db);
        }
      },
    );

    // Create the DAO after the database is open and migrated.
    _jobCacheDao = JobCacheDao(_localDb);
  }

  // ── Users (Supabase profiles table) ───────────────────────────────────────

  Future<void> insertUser(ProfileUser user) async {
    // Use upsert instead of insert: the handle_new_user() DB trigger fires the
    // moment auth.signUp() succeeds and inserts a skeleton profile row.
    // If we then INSERT again with the same uid we get a duplicate-key error.
    // Upsert merges on the primary key (uid), so the trigger's skeleton row is
    // overwritten with the full profile data from the app.
    await _client.from('profiles').upsert(user.toSupabaseMap());
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

  /// Fetches a uid → displayName map for the given list of UIDs in one query.
  Future<Map<String, String>> getDisplayNamesByIds(List<String> uids) async {
    if (uids.isEmpty) return {};
    final rows = await _client
        .from('profiles')
        .select('uid, display_name')
        .inFilter('uid', uids);
    return {
      for (final r in rows)
        (r['uid'] as String): (r['display_name'] as String? ?? 'Unknown'),
    };
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

  /// Propagates a new display name to every table that stores a denormalized
  /// copy of the user's name.
  ///
  /// Called automatically by [AppState.updateProfile] when the name changes.
  /// All updates run in parallel via [Future.wait].
  Future<void> updateUserDisplayNameEverywhere(
      String uid, String newName) async {
    await Future.wait([
      // Client-side denormalized names
      _client.from('job_posts')
          .update({'client_name': newName}).eq('client_id', uid),
      _client.from('service_orders')
          .update({'client_name': newName}).eq('client_id', uid),
      _client.from('projects')
          .update({'client_name': newName}).eq('client_id', uid),

      // Freelancer-side denormalized names
      _client.from('freelancer_services')
          .update({'freelancer_name': newName}).eq('freelancer_id', uid),
      _client.from('applications')
          .update({'freelancer_name': newName}).eq('freelancer_id', uid),
      _client.from('service_orders')
          .update({'freelancer_name': newName}).eq('freelancer_id', uid),
      _client.from('projects')
          .update({'freelancer_name': newName}).eq('freelancer_id', uid),

      // Shared / marketplace
      _client.from('posts')
          .update({'owner_name': newName}).eq('owner_id', uid),
      _client.from('reviews')
          .update({'reviewer_name': newName}).eq('reviewer_id', uid),
      _client.from('chat_rooms')
          .update({'last_sender_name': newName}).eq('last_sender_id', uid),

      // Chat messages — each message caches the sender's name for performance.
      // Must be updated so chat history shows the current name, not the old one.
      _client.from('chat_messages')
          .update({'sender_name': newName}).eq('sender_id', uid),
    ]);
  }

  /// Hard-delete for accounts that never completed email verification.
  /// RLS enforces that only the owner can delete, and only while the account
  /// is still in pendingVerification status (see profiles_own_delete policy).
  Future<void> deleteOwnProfile(String uid) async {
    await _client.from('profiles').delete().eq('uid', uid);
  }

  /// Soft-delete: sets account_status=deactivated without removing the row.
  /// Keeps related posts, projects and reviews intact for audit traceability.
  Future<void> deactivateUser(String uid) async {
    await _client.from('profiles').update({
      'account_status': AccountStatus.deactivated.name,
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('uid', uid);
  }

  /// Cleans up public-facing content when a user deactivates their account.
  ///
  /// - **Freelancer**: hides all active services (→ inactive) and withdraws
  ///   every pending job application they submitted.
  /// - **Client**: closes all open job posts (→ closed) so freelancers stop
  ///   seeing them in the browse feed.
  Future<void> deactivateUserContent(String uid, UserRole role) async {
    final now = DateTime.now().toIso8601String();
    if (role == UserRole.freelancer) {
      // Hide services from browse feed
      await _client.from('freelancer_services').update({
        'status': ServiceStatus.inactive.name,
        'updated_at': now,
      }).eq('freelancer_id', uid).eq('status', ServiceStatus.active.name);

      // Withdraw all pending applications
      await _client.from('applications').update({
        'status': ApplicationStatus.withdrawn.name,
        'updated_at': now,
      }).eq('freelancer_id', uid).eq('status', ApplicationStatus.pending.name);
    } else if (role == UserRole.client) {
      // Close open job posts so they stop appearing in the browse feed
      await _client.from('job_posts').update({
        'status': JobStatus.closed.name,
        'updated_at': now,
      }).eq('client_id', uid).eq('status', JobStatus.open.name);
    }
  }

  /// Admin: set a user's account status (active, restricted, deactivated).
  Future<void> updateAccountStatus(String uid, AccountStatus status) async {
    await _client.from('profiles').update({
      'account_status': status.name,
      'is_active': status != AccountStatus.deactivated,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('uid', uid);
  }

  /// Admin: fetch users filtered by account status.
  Future<List<ProfileUser>> getUsersByStatus(AccountStatus status) async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('account_status', status.name)
        .order('created_at', ascending: false);
    return rows.map(ProfileUser.fromMap).toList();
  }

  // ── Freelancer Requests ────────────────────────────────────────────────────

  Future<FreelancerRequest?> getPendingFreelancerRequest(
      String userId) async {
    final row = await _client
        .from('freelancer_requests')
        .select()
        .eq('requester_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    return row == null ? null : FreelancerRequest.fromMap(row);
  }

  Future<FreelancerRequest?> getLatestFreelancerRequest(
      String userId) async {
    final rows = await _client
        .from('freelancer_requests')
        .select()
        .eq('requester_id', userId)
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : FreelancerRequest.fromMap(rows.first);
  }

  Future<List<FreelancerRequest>> getAllFreelancerRequests(
      {RequestStatus? status}) async {
    var builder = _client.from('freelancer_requests').select();
    if (status != null) {
      final rows = await builder
          .eq('status', status.name)
          .order('created_at', ascending: false);
      return rows.map((r) => FreelancerRequest.fromMap(r)).toList();
    }
    final rows =
        await builder.order('created_at', ascending: false);
    return rows.map((r) => FreelancerRequest.fromMap(r)).toList();
  }

  Future<FreelancerRequest> insertFreelancerRequest(
      FreelancerRequest req) async {
    final row = await _client
        .from('freelancer_requests')
        .insert(req.toMap())
        .select()
        .single();
    return FreelancerRequest.fromMap(row);
  }

  Future<FreelancerRequest> updateFreelancerRequestStatus(
    String id,
    RequestStatus status, {
    String? adminNote,
    String? reviewedBy,
  }) async {
    final row = await _client.from('freelancer_requests').update({
      'status': status.name,
      if (adminNote != null) 'admin_note': adminNote,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).select().single();
    return FreelancerRequest.fromMap(row);
  }

  // ── Appeals ────────────────────────────────────────────────────────────────

  Future<List<Appeal>> getAppealsForUser(String userId) async {
    final rows = await _client
        .from('appeals')
        .select()
        .eq('appellant_id', userId)
        .order('created_at', ascending: false);
    return rows.map(Appeal.fromMap).toList();
  }

  Future<Appeal?> getOpenAppealForUser(String userId) async {
    final row = await _client
        .from('appeals')
        .select()
        .eq('appellant_id', userId)
        .eq('status', 'open')
        .maybeSingle();
    return row == null ? null : Appeal.fromMap(row);
  }

  Future<List<Appeal>> getAllAppeals({AppealStatus? status}) async {
    var builder = _client.from('appeals').select();
    if (status != null) {
      final rows = await builder
          .eq('status', status.dbValue)
          .order('created_at', ascending: false);
      return rows.map((r) => Appeal.fromMap(r)).toList();
    }
    final rows = await builder.order('created_at', ascending: false);
    return rows.map((r) => Appeal.fromMap(r)).toList();
  }

  Future<Appeal> insertAppeal(Appeal appeal) async {
    final row = await _client
        .from('appeals')
        .insert(appeal.toMap())
        .select()
        .single();
    return Appeal.fromMap(row);
  }

  Future<Appeal> updateAppealStatus(
    String id,
    AppealStatus status, {
    String? adminResponse,
    String? reviewedBy,
  }) async {
    final row = await _client.from('appeals').update({
      'status': status.dbValue,
      if (adminResponse != null) 'admin_response': adminResponse,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).select().single();
    return Appeal.fromMap(row);
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

  /// All applications sent to jobs posted by [clientId].
  Future<List<ApplicationItem>> getApplicationsByClient(
      String clientId) async {
    final rows = await _client
        .from('applications')
        .select()
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    return rows.map(ApplicationItem.fromMap).toList();
  }

  /// All applications submitted by [freelancerId].
  Future<List<ApplicationItem>> getApplicationsByFreelancer(
      String freelancerId) async {
    final rows = await _client
        .from('applications')
        .select()
        .eq('freelancer_id', freelancerId)
        .order('created_at', ascending: false);
    return rows.map(ApplicationItem.fromMap).toList();
  }

  Future<bool> hasApplied(String jobId, String freelancerId) async {
    // Withdrawn applications do not count — the freelancer is allowed to re-apply.
    final rows = await _client
        .from('applications')
        .select('id')
        .eq('job_id', jobId)
        .eq('freelancer_id', freelancerId)
        .neq('status', 'withdrawn');
    return rows.isNotEmpty;
  }

  /// Returns the count of currently ACTIVE (pending) applications for a job.
  ///
  /// Uses a SECURITY DEFINER RPC so the count is visible to ALL users
  /// (freelancers, clients, guests) regardless of the RLS policy on the
  /// applications table — only the aggregate count is exposed, never
  /// individual rows.  Withdrawn and rejected applications are excluded.
  Future<int> getJobApplicationCount(String jobId) async {
    final result = await _client.rpc(
      'get_job_pending_application_count',
      params: {'p_job_id': jobId},
    );
    return (result as int?) ?? 0;
  }

  Future<void> updateApplicationStatus(
      String appId, ApplicationStatus status) async {
    await _client.from('applications').update({
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', appId);
  }

  /// Rejects all pending applications for a job except the winner.
  /// Returns the list of rejected applications so callers can send
  /// rejection notifications to each affected freelancer.
  Future<List<ApplicationItem>> rejectAllOtherApplications(
      String jobId, String winnerAppId) async {
    // Fetch the pending losers BEFORE updating so we have their data.
    final rows = await _client
        .from('applications')
        .select()
        .eq('job_id', jobId)
        .neq('id', winnerAppId)
        .eq('status', 'pending');
    final rejected = (rows as List)
        .map((r) => ApplicationItem.fromMap(r as Map<String, dynamic>))
        .toList();

    // Bulk-update them to rejected.
    await _client.from('applications').update({
      'status': ApplicationStatus.rejected.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('job_id', jobId).neq('id', winnerAppId).eq('status', 'pending');

    return rejected;
  }

  /// Rejects ALL pending applications for a job (used when the job is
  /// closed or cancelled without accepting any specific application).
  /// Returns the list of rejected applications so callers can notify them.
  Future<List<ApplicationItem>> rejectAllPendingApplicationsForJob(
      String jobId) async {
    // Fetch pending applicants BEFORE the bulk update.
    final rows = await _client
        .from('applications')
        .select()
        .eq('job_id', jobId)
        .eq('status', 'pending');
    final rejected = (rows as List)
        .map((r) => ApplicationItem.fromMap(r as Map<String, dynamic>))
        .toList();

    await _client.from('applications').update({
      'status': ApplicationStatus.rejected.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('job_id', jobId).eq('status', 'pending');

    return rejected;
  }

  Future<void> updateApplication(ApplicationItem app) async {
    await _client
        .from('applications')
        .update(app.toSupabaseMap())
        .eq('id', app.id);
  }

  // ── Service Orders ─────────────────────────────────────────────────────────

  Future<List<ServiceOrder>> getServiceOrdersByClient(
      String clientId) async {
    final rows = await _client
        .from('service_orders')
        .select()
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    return rows.map(ServiceOrder.fromMap).toList();
  }

  Future<List<ServiceOrder>> getServiceOrdersByFreelancer(
      String freelancerId) async {
    final rows = await _client
        .from('service_orders')
        .select()
        .eq('freelancer_id', freelancerId)
        .order('created_at', ascending: false);
    return rows.map(ServiceOrder.fromMap).toList();
  }

  Future<ServiceOrder?> getServiceOrderById(String id) async {
    final row = await _client
        .from('service_orders')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ServiceOrder.fromMap(row);
  }

  Future<void> insertServiceOrder(ServiceOrder order) async {
    await _client
        .from('service_orders')
        .upsert(order.toSupabaseMap());
  }

  Future<void> updateServiceOrderStatus(
    String id,
    ServiceOrderStatus status, {
    String? freelancerNote,
  }) async {
    await _client.from('service_orders').update({
      'status': status.name,
      if (freelancerNote != null) 'freelancer_note': freelancerNote,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Projects ───────────────────────────────────────────────────────────────

  Future<void> insertProject(ProjectItem project) async {
    await _client.from('projects').insert(project.toSupabaseMap());
  }

  Future<void> updateProject(ProjectItem project) async {
    await _client
        .from('projects')
        .update(project.toSupabaseMap())
        .eq('id', project.id);
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

  Future<ProjectItem?> getProjectByApplicationId(String applicationId) async {
    final row = await _client
        .from('projects')
        .select()
        .eq('application_id', applicationId)
        .maybeSingle();
    return row == null ? null : ProjectItem.fromMap(row);
  }

  /// Typed status update — also optionally sets [clientSignatureUrl] and
  /// [startDate] in the same round trip.
  Future<void> updateProjectStatusEnum(
    String projectId,
    ProjectStatus status, {
    String? clientSignatureUrl,
    DateTime? startDate,
    String? cancellationReason,
  }) async {
    await _client.from('projects').update({
      'status': status.name,
      if (clientSignatureUrl != null)
        'client_signature_url': clientSignatureUrl,
      if (startDate != null)
        'start_date': startDate.toIso8601String(),
      if (cancellationReason != null)
        'cancellation_reason': cancellationReason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  /// Marks delivery mode as 'single'. Project stays pendingStart —
  /// status moves to inProgress only after the client pays (via [updateProjectStatusEnum]).
  Future<void> markSingleDeliveryMode(String projectId) async {
    await _client.from('projects').update({
      'delivery_mode': 'single',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  /// Stores the freelancer's single-delivery URL (status stays inProgress).
  Future<void> submitSingleDelivery(
      String projectId, String deliverableUrl) async {
    await _client.from('projects').update({
      'single_deliverable_url': deliverableUrl,
      'single_rejection_note': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  /// Client rejects single delivery — clears URL so freelancer can re-submit.
  Future<void> rejectSingleDelivery(
      String projectId, String reason) async {
    await _client.from('projects').update({
      'single_deliverable_url': null,
      'single_rejection_note': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }

  /// Legacy string-based update kept for any remaining call sites.
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
    if (projectId.isEmpty) return [];
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
      'status': MilestoneStatus.completed.name,
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

  Future<void> rejectMilestone(String id, String reason) async {
    await _client.from('milestones').update({
      'status': MilestoneStatus.rejected.name,
      'rejection_note': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> requestMilestoneExtension(String id, int days) async {
    await _client.from('milestones').update({
      'extension_days': days,
      'extension_requested_at': DateTime.now().toIso8601String(),
      'extension_approved': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> approveMilestoneExtension(String id, int days) async {
    await _client.from('milestones').update({
      'extension_approved': true,
      'extension_days': days,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Batch-insert an entire milestone plan (upsert to allow re-proposals).
  Future<void> batchInsertMilestones(List<MilestoneItem> milestones) async {
    final rows = milestones.map((m) => m.toSupabaseMap()).toList();
    await _client.from('milestones').upsert(rows);
  }

  /// Advance the next queued milestone to [MilestoneStatus.inProgress].
  /// Called after a milestone is approved+paid.
  Future<void> advanceMilestoneToNext(
      String projectId, int completedOrderIndex) async {
    final rows = await _client
        .from('milestones')
        .select()
        .eq('project_id', projectId)
        .eq('status', MilestoneStatus.approved.name)
        .order('order_index', ascending: true)
        .limit(1);

    if (rows.isNotEmpty) {
      final nextId = rows.first['id'] as String;
      await _client.from('milestones').update({
        'status': MilestoneStatus.inProgress.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', nextId);
    }
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

  /// Published reviews where [userId] is the reviewee.
  Future<List<ReviewItem>> getReviewsForUser(String userId) async {
    final rows = await _client
        .from('reviews')
        .select()
        .eq('reviewee_id', userId)
        .eq('status', 'published')
        .order('created_at', ascending: false);
    return rows.map(ReviewItem.fromMap).toList();
  }

  /// All reviews (any status) authored by [userId].
  Future<List<ReviewItem>> getReviewsByUser(String userId) async {
    final rows = await _client
        .from('reviews')
        .select()
        .eq('reviewer_id', userId)
        .order('created_at', ascending: false);
    return rows.map(ReviewItem.fromMap).toList();
  }

  /// Admin: all reviews with status = reported.
  Future<List<ReviewItem>> getReportedReviews() async {
    final rows = await _client
        .from('reviews')
        .select()
        .eq('status', 'reported')
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

  /// Append [reporterId] to `reported_by` and set status → `reported`.
  Future<void> reportReview(String reviewId, String reporterId) async {
    // Fetch current reported_by list first
    final rows = await _client
        .from('reviews')
        .select('reported_by')
        .eq('id', reviewId)
        .limit(1);
    if (rows.isEmpty) return;

    final existing = List<String>.from(
        (rows.first['reported_by'] as List?) ?? []);
    if (!existing.contains(reporterId)) existing.add(reporterId);

    await _client.from('reviews').update({
      'reported_by': existing,
      'status': 'reported',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reviewId);
  }

  /// Admin: set [status] on a review directly.
  Future<void> setReviewStatus(
      String reviewId, ReviewStatus status) async {
    await _client.from('reviews').update({
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reviewId);
  }

  /// Recalculates [averageRating] and [totalReviews] for any user (not
  /// just freelancers) — counts only `published` reviews where the user
  /// is the reviewee.
  Future<void> updateRevieweeRatingStats(String userId) async {
    final rows = await _client
        .from('reviews')
        .select('stars')
        .eq('reviewee_id', userId)
        .eq('status', 'published');

    if (rows.isEmpty) {
      await _client.from('profiles').update({
        'average_rating': 0.0,
        'total_reviews': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('uid', userId);
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
    }).eq('uid', userId);
  }

  /// Legacy alias — kept so old callers still compile.
  Future<void> updateFreelancerRatingStats(String freelancerId) =>
      updateRevieweeRatingStats(freelancerId);

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

    // Only count milestones that are fully completed (deliverable approved +
    // payment released to the freelancer).
    // 'approved' = plan was approved, work hasn't started yet — NOT earnings.
    // 'completed' = client signed off the deliverable and released payment ✓
    //
    // Limit to the last 6 months to match the chart title.
    final sixMonthsAgo = DateTime.now()
        .subtract(const Duration(days: 183))
        .toIso8601String();

    final milestoneRows = await _client
        .from('milestones')
        .select('payment_amount,updated_at')
        .inFilter('project_id', projectIds)
        .eq('status', 'completed')
        .gte('updated_at', sixMonthsAgo)
        .order('updated_at', ascending: true);

    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    // Use a LinkedHashMap-ordered map so chart bars appear chronologically.
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

  Future<Map<int, int>> getRatingDistribution(String userId) async {
    final rows = await _client
        .from('reviews')
        .select('stars')
        .eq('reviewee_id', userId)
        .eq('status', 'published');

    final Map<int, int> result = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final row in rows) {
      final stars = (row['stars'] as num).toInt();
      result[stars] = (result[stars] ?? 0) + 1;
    }
    return result;
  }

  /// Monthly average rating for [userId] over all time (published reviews only).
  /// Returns a map keyed by "Mon YYYY" e.g. `{'Jan 2025': 4.2, 'Feb 2025': 4.8}`.
  Future<Map<String, double>> getMonthlyRatingTrend(String userId) async {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final rows = await _client
        .from('reviews')
        .select('stars,created_at')
        .eq('reviewee_id', userId)
        .eq('status', 'published')
        .order('created_at', ascending: true);

    final Map<String, List<int>> byMonth = {};
    for (final row in rows) {
      final date = _parseDate(row['created_at']);
      final key = '${monthNames[date.month - 1]} ${date.year}';
      byMonth.putIfAbsent(key, () => []).add((row['stars'] as num).toInt());
    }

    return byMonth.map(
      (k, stars) => MapEntry(
        k,
        stars.reduce((a, b) => a + b) / stars.length,
      ),
    );
  }

  // ── Payment Records ────────────────────────────────────────────────────────

  Future<PaymentRecord?> getPaymentRecordForProject(
      String projectId) async {
    final row = await _client
        .from('payment_records')
        .select()
        .eq('project_id', projectId)
        .maybeSingle();
    return row == null ? null : PaymentRecord.fromMap(row);
  }

  Future<void> insertPaymentRecord(PaymentRecord record) async {
    await _client
        .from('payment_records')
        .insert(record.toSupabaseMap());
  }

  Future<void> updatePaymentRecord(PaymentRecord record) async {
    await _client
        .from('payment_records')
        .update(record.toSupabaseMap())
        .eq('id', record.id);
  }

  // ── Payout Records ─────────────────────────────────────────────────────────

  Future<void> insertPayoutRecord(PayoutRecord payout) async {
    await _client
        .from('payout_records')
        .insert(payout.toSupabaseMap());
  }

  Future<List<PayoutRecord>> getPayoutsForProject(
      String projectId) async {
    final rows = await _client
        .from('payout_records')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: true);
    return rows.map(PayoutRecord.fromMap).toList();
  }

  Future<List<PayoutRecord>> getPayoutsForPayment(
      String paymentId) async {
    final rows = await _client
        .from('payout_records')
        .select()
        .eq('payment_id', paymentId)
        .order('created_at', ascending: true);
    return rows.map(PayoutRecord.fromMap).toList();
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

  // ── Categories ────────────────────────────────────────────────────────────

  /// Fetch all categories ordered by sort_order.
  Future<List<CategoryItem>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => CategoryItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ── Portfolio Items ────────────────────────────────────────────────────────

  Future<List<PortfolioItem>> getPortfolioItems(String freelancerId) async {
    final rows = await _client
        .from('portfolio_items')
        .select()
        .eq('freelancer_id', freelancerId)
        .order('created_at', ascending: false);
    return rows.map((r) => PortfolioItem.fromMap(r)).toList();
  }

  Future<void> insertPortfolioItem(PortfolioItem item) async {
    await _client.from('portfolio_items').insert(item.toMap());
  }

  Future<void> updatePortfolioItem(PortfolioItem item) async {
    await _client
        .from('portfolio_items')
        .update(item.toMap())
        .eq('id', item.id);
  }

  Future<void> deletePortfolioItem(String id) async {
    await _client.from('portfolio_items').delete().eq('id', id);
  }

  // ── Job Posts ──────────────────────────────────────────────────────────────

  /// Fetch open job posts with optional search, category, and budget filters.
  /// Results are ordered by created_at DESC and support pagination.
  Future<List<JobPost>> getOpenJobPosts({
    String? search,
    String? category,
    double? minBudget,
    double? maxBudget,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('job_posts')
        .select()
        .eq('status', JobStatus.open.name);

    if (category != null) {
      query = query.eq('category', category);
    }
    if (minBudget != null) {
      query = query.gte('budget_max', minBudget);
    }
    if (maxBudget != null) {
      query = query.lte('budget_min', maxBudget);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    var posts = rows.map(JobPost.fromMap).toList();

    // Client-side search (title, description, skills) — cheaper than
    // full-text for the expected dataset size.
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      posts = posts.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.requiredSkills.any((s) => s.toLowerCase().contains(q)) ||
            p.clientName.toLowerCase().contains(q);
      }).toList();
    }
    return posts;
  }

  /// All non-deleted posts belonging to a specific client.
  Future<List<JobPost>> getJobPostsByClient(String clientId) async {
    final rows = await _client
        .from('job_posts')
        .select()
        .eq('client_id', clientId)
        .neq('status', JobStatus.deleted.name)
        .order('created_at', ascending: false);
    return rows.map(JobPost.fromMap).toList();
  }

  Future<JobPost?> getJobPostById(String id) async {
    final row = await _client
        .from('job_posts')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : JobPost.fromMap(row);
  }

  Future<JobPost> insertJobPost(JobPost post) async {
    final row = await _client
        .from('job_posts')
        .insert(post.toSupabaseWriteMap())
        .select()
        .single();
    return JobPost.fromMap(row);
  }

  Future<JobPost> updateJobPost(JobPost post) async {
    final row = await _client
        .from('job_posts')
        .update(post.toSupabaseWriteMap())
        .eq('id', post.id)
        .select()
        .single();
    return JobPost.fromMap(row);
  }

  Future<void> updateJobPostStatus(String id, JobStatus status) async {
    await _client.from('job_posts').update({
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Soft-deletes a job post by setting its status to [JobStatus.deleted].
  /// The row is retained in Supabase for audit / data-integrity purposes.
  Future<void> deleteJobPost(String id) async {
    await _client.from('job_posts').update({
      'status': JobStatus.deleted.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Atomically increments view_count via RPC or a simple update.
  Future<void> incrementJobPostViewCount(String id) async {
    // Uses Postgres raw increment to avoid race conditions.
    await _client.rpc('increment_job_post_view', params: {'post_id': id});
  }

  /// Atomically increments application_count on the job post row.
  Future<void> incrementJobPostApplicationCount(String id) async {
    await _client.rpc('increment_job_application_count', params: {'post_id': id});
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

  /// Replace the columnar cache with the 20 most-recent open posts and record
  /// the sync timestamp. Delegates to [JobCacheDao.replaceAll].
  Future<void> cacheJobPosts(List<JobPost> posts) =>
      _jobCacheDao.replaceAll(posts);

  /// All cached job posts, ordered newest-first.
  /// Delegates to [JobCacheDao.getAll].
  Future<List<JobPost>> getCachedJobPosts() => _jobCacheDao.getAll();

  /// When was the job cache last successfully synced from Supabase?
  /// Returns `null` if the cache has never been populated.
  Future<DateTime?> getJobCacheLastSyncedAt() => _jobCacheDao.lastSyncedAt();

  /// `true` when the cache is older than [JobCacheDao.kStaleDuration] or empty.
  Future<bool> isJobCacheStale() => _jobCacheDao.isStale();

  // ── Freelancer Services ────────────────────────────────────────────────────

  /// Fetch active service listings with optional search, category, and
  /// max-price filters. Results are ordered newest-first and support paging.
  Future<List<FreelancerService>> getActiveFreelancerServices({
    String? search,
    String? category,
    double? maxPrice,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('freelancer_services')
        .select()
        .eq('status', ServiceStatus.active.name);

    if (category != null) {
      query = query.eq('category', category);
    }
    if (maxPrice != null) {
      // Services whose minimum price is within the budget
      query = query.lte('price_min', maxPrice);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    var services = rows.map(FreelancerService.fromMap).toList();

    // Client-side text search across title, description, tags and name.
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      services = services.where((s) {
        return s.title.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q) ||
            s.tags.any((t) => t.toLowerCase().contains(q)) ||
            s.freelancerName.toLowerCase().contains(q);
      }).toList();
    }
    return services;
  }

  /// All non-deleted services owned by a specific freelancer.
  Future<List<FreelancerService>> getFreelancerServicesByOwner(
      String freelancerId) async {
    final rows = await _client
        .from('freelancer_services')
        .select()
        .eq('freelancer_id', freelancerId)
        .neq('status', ServiceStatus.deleted.name)
        .order('created_at', ascending: false);
    return rows.map(FreelancerService.fromMap).toList();
  }

  Future<FreelancerService?> getFreelancerServiceById(String id) async {
    final row = await _client
        .from('freelancer_services')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : FreelancerService.fromMap(row);
  }

  Future<FreelancerService> insertFreelancerService(
      FreelancerService service) async {
    final row = await _client
        .from('freelancer_services')
        .insert(service.toSupabaseWriteMap())
        .select()
        .single();
    return FreelancerService.fromMap(row);
  }

  Future<FreelancerService> updateFreelancerService(
      FreelancerService service) async {
    final row = await _client
        .from('freelancer_services')
        .update(service.toSupabaseWriteMap())
        .eq('id', service.id)
        .select()
        .single();
    return FreelancerService.fromMap(row);
  }

  Future<void> updateFreelancerServiceStatus(
      String id, ServiceStatus status) async {
    await _client.from('freelancer_services').update({
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Atomically increments view_count via a Postgres RPC.
  Future<void> incrementServiceViewCount(String id) async {
    await _client
        .rpc('increment_service_view', params: {'service_id': id});
  }

  /// Atomically increments order_count on the service row when a project
  /// that originated from a service order is completed.
  Future<void> incrementServiceOrderCount(String serviceId) async {
    await _client
        .rpc('increment_service_order_count', params: {'svc_id': serviceId});
  }

  // ── Service cache (SQLite) ─────────────────────────────────────────────────

  /// Replace the cached_freelancer_services table with the 20 newest active
  /// service listings.
  Future<void> cacheFreelancerServices(
      List<FreelancerService> services) async {
    final batch = _localDb.batch();
    batch.delete('cached_freelancer_services');
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final service in services.take(20)) {
      batch.insert(
        'cached_freelancer_services',
        {
          'id': service.id,
          'payload': jsonEncode(service.toSqliteMap()),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<FreelancerService>> getCachedFreelancerServices() async {
    final rows = await _localDb.query(
      'cached_freelancer_services',
      orderBy: 'cached_at DESC',
    );
    return rows.map((row) {
      final decoded =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return FreelancerService.fromMap(decoded);
    }).toList();
  }

  // ── Dispute Records ────────────────────────────────────────────────────────

  Future<DisputeRecord?> getDisputeById(String id) async {
    final row = await _client
        .from('dispute_records')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : DisputeRecord.fromMap(row);
  }

  Future<DisputeRecord?> getActiveDisputeForProject(String projectId) async {
    final row = await _client
        .from('dispute_records')
        .select()
        .eq('project_id', projectId)
        .inFilter('status', ['open', 'under_review'])
        .maybeSingle();
    return row == null ? null : DisputeRecord.fromMap(row);
  }

  Future<List<DisputeRecord>> getDisputesByStatus(
      DisputeStatus status) async {
    final rows = await _client
        .from('dispute_records')
        .select()
        .eq('status', status.name)
        .order('created_at', ascending: false);
    return rows.map(DisputeRecord.fromMap).toList();
  }

  Future<List<DisputeRecord>> getOpenDisputes() async {
    final rows = await _client
        .from('dispute_records')
        .select()
        .inFilter('status', ['open', 'under_review'])
        .order('created_at', ascending: false);
    return rows.map(DisputeRecord.fromMap).toList();
  }

  Future<List<DisputeRecord>> getDisputesForUser(String userId) async {
    final rows = await _client
        .from('dispute_records')
        .select()
        .or('client_id.eq.$userId,freelancer_id.eq.$userId')
        .order('created_at', ascending: false);
    return rows.map(DisputeRecord.fromMap).toList();
  }

  Future<void> insertDisputeRecord(DisputeRecord record) async {
    await _client
        .from('dispute_records')
        .insert(record.toSupabaseMap());
  }

  Future<void> updateDisputeRecord(DisputeRecord record) async {
    await _client
        .from('dispute_records')
        .update(record.toSupabaseMap())
        .eq('id', record.id);
  }

  // ── Overdue Records ────────────────────────────────────────────────────────

  Future<OverdueRecord?> getOverdueRecordForMilestone(
      String milestoneId) async {
    final rows = await _client
        .from('overdue_records')
        .select()
        .eq('milestone_id', milestoneId)
        .limit(1);
    if (rows.isEmpty) return null;
    return OverdueRecord.fromMap(rows.first);
  }

  Future<List<OverdueRecord>> getActiveOverdueRecordsForProject(
      String projectId) async {
    final rows = await _client
        .from('overdue_records')
        .select()
        .eq('project_id', projectId)
        .eq('auto_resolved', false)
        .order('created_at', ascending: false);
    return rows.map(OverdueRecord.fromMap).toList();
  }

  Future<List<OverdueRecord>> getAllActiveOverdueRecords() async {
    final rows = await _client
        .from('overdue_records')
        .select()
        .eq('auto_resolved', false)
        .isFilter('triggered_at', null)
        .order('milestone_deadline', ascending: true);
    return rows.map(OverdueRecord.fromMap).toList();
  }

  Future<void> insertOverdueRecord(OverdueRecord record) async {
    await _client.from('overdue_records').insert(record.toSupabaseMap());
  }

  Future<void> updateOverdueRecord(OverdueRecord record) async {
    await _client
        .from('overdue_records')
        .update(record.toSupabaseMap())
        .eq('id', record.id);
  }

  Future<void> markOverdueRecordResolved(String id) async {
    await _client.from('overdue_records').update({
      'auto_resolved': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Milestone: deny extension ──────────────────────────────────────────────

  /// Clears the pending extension request without approving it.
  Future<void> denyMilestoneExtension(String milestoneId) async {
    await _client.from('milestones').update({
      'extension_days': null,
      'extension_requested_at': null,
      'extension_approved': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', milestoneId);
  }

  // ── In-App Notifications ───────────────────────────────────────────────────

  Future<void> insertNotification(InAppNotification n) async {
    try {
      await _client.from('in_app_notifications').insert(n.toSupabaseMap());
    } catch (e) {
      // Log so RLS / network failures are visible during development.
      // ignore: avoid_print
      print('[NotificationInsert] failed for type=${n.type.name} '
          'userId=${n.userId}: $e');
      rethrow;
    }
  }

  Future<List<InAppNotification>> getNotificationsForUser(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('in_app_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(InAppNotification.fromMap).toList();
  }

  Future<int> unreadNotificationCount(String userId) async {
    final result = await _client
        .from('in_app_notifications')
        .select()
        .eq('user_id', userId)
        .eq('is_read', false)
        .count();
    return result.count;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client.from('in_app_notifications').update({
      'is_read': true,
    }).eq('id', notificationId);
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await _client.from('in_app_notifications').update({
      'is_read': true,
    }).eq('user_id', userId).eq('is_read', false);
  }

  /// Supabase Realtime stream — emits every time a notification is
  /// inserted or updated for [userId].  The app uses this to update the
  /// badge and inbox without the user having to pull-to-refresh.
  Stream<List<InAppNotification>> notificationsStream(String userId) =>
      _client
          .from('in_app_notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50)
          .map((rows) => rows.map(InAppNotification.fromMap).toList());

  // ── Chat Rooms ─────────────────────────────────────────────────────────────

  /// All rooms the user participates in, ordered by last message time.
  Future<List<ChatRoom>> getChatRoomsForUser(String userId) async {
    final rows = await _client
        .from('chat_rooms')
        .select()
        .contains('participant_ids', [userId])
        .order('last_message_at', ascending: false, nullsFirst: false);
    return rows.map(ChatRoom.fromMap).toList();
  }

  Future<ChatRoom?> getChatRoomById(String id) async {
    final row = await _client
        .from('chat_rooms')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ChatRoom.fromMap(row);
  }

  /// Find an existing direct room between exactly these two participants.
  Future<ChatRoom?> getDirectRoom(String userId1, String userId2) async {
    // Filter rooms that contain both participants using @> (contains)
    final rows = await _client
        .from('chat_rooms')
        .select()
        .eq('type', 'direct')
        .contains('participant_ids', [userId1, userId2]);
    // Verify it has exactly these 2 participants
    for (final row in rows) {
      final room = ChatRoom.fromMap(row);
      if (room.participantIds.length == 2 &&
          room.participantIds.contains(userId1) &&
          room.participantIds.contains(userId2)) {
        return room;
      }
    }
    return null;
  }

  /// Find the project room for the given project, if it exists.
  Future<ChatRoom?> getProjectRoom(String projectId) async {
    final row = await _client
        .from('chat_rooms')
        .select()
        .eq('type', 'project')
        .eq('project_id', projectId)
        .maybeSingle();
    return row == null ? null : ChatRoom.fromMap(row);
  }

  Future<ChatRoom?> getAppealRoom(String appealId) async {
    final row = await _client
        .from('chat_rooms')
        .select()
        .eq('type', 'appeal')
        .eq('appeal_id', appealId)
        .maybeSingle();
    return row == null ? null : ChatRoom.fromMap(row);
  }

  Future<ChatRoom?> getDisputeRoom(String disputeId) async {
    final row = await _client
        .from('chat_rooms')
        .select()
        .eq('type', 'dispute')
        .eq('dispute_id', disputeId)
        .maybeSingle();
    return row == null ? null : ChatRoom.fromMap(row);
  }

  Future<ChatRoom> insertChatRoom(ChatRoom room) async {
    final row = await _client
        .from('chat_rooms')
        .insert(room.toSupabaseMap())
        .select()
        .single();
    return ChatRoom.fromMap(row);
  }

  Future<void> updateChatRoom(ChatRoom room) async {
    await _client
        .from('chat_rooms')
        .update(room.toSupabaseMap())
        .eq('id', room.id);
  }

  /// Add a participant to an existing room (e.g. admin joins a dispute room).
  Future<void> addParticipantToRoom(String roomId, String userId) async {
    // Use Postgres array append via raw SQL to avoid race conditions
    await _client.rpc('append_chat_participant',
        params: {'room_id': roomId, 'user_id': userId});
  }

  // ── Chat Messages ──────────────────────────────────────────────────────────

  Future<List<ChatMessage>> getMessagesForRoom(
    String roomId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    // Reverse so oldest-first for display
    return rows.reversed.map(ChatMessage.fromMap).toList();
  }

  Future<ChatMessage> insertChatMessage(ChatMessage message) async {
    final row = await _client
        .from('chat_messages')
        .insert(message.toSupabaseMap())
        .select()
        .single();
    return ChatMessage.fromMap(row);
  }

  /// Supabase Realtime stream of new messages for a specific room.
  Stream<List<Map<String, dynamic>>> chatMessagesStream(String roomId) =>
      _client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', roomId)
          .order('created_at', ascending: true)
          .map((rows) => rows.cast<Map<String, dynamic>>());

  /// Supabase Realtime stream of chat rooms for a user.
  /// NOTE: Supabase Realtime stream() doesn't support array contains,
  /// so we stream all and filter on the client side.
  Stream<List<ChatRoom>> chatRoomsStream(String userId) => _client
      .from('chat_rooms')
      .stream(primaryKey: ['id'])
      .order('last_message_at', ascending: false)
      .map((rows) => rows
          .map(ChatRoom.fromMap)
          .where((r) => r.participantIds.contains(userId))
          .toList());

  // ── Chat Reads ─────────────────────────────────────────────────────────────

  /// Upsert the user's last-read timestamp for a room.
  Future<void> markRoomRead(String roomId, String userId) async {
    // Use a SECURITY DEFINER RPC so the timestamp is set by the Supabase
    // server (PostgreSQL NOW()) rather than the device clock.
    // This eliminates clock-skew where a device timestamp could be slightly
    // earlier than the message's server timestamp, causing the room to appear
    // unread again after the Realtime stream refreshes the unread map.
    await _client.rpc('mark_chat_room_read', params: {
      'p_room_id': roomId,
      'p_user_id': userId,
    });
  }

  /// Get last-read timestamps for all rooms the user is in.
  Future<Map<String, DateTime>> getChatReadTimestamps(String userId) async {
    final rows = await _client
        .from('chat_reads')
        .select()
        .eq('user_id', userId);
    final Map<String, DateTime> result = {};
    for (final row in rows) {
      final roomId = row['room_id'] as String;
      final ts = row['read_until'];
      if (ts != null) {
        final parsed =
            ts is String ? DateTime.tryParse(ts)?.toUtc() : null;
        if (parsed != null) {
          // Keep only the most recent timestamp per room (guards against
          // duplicate rows if the upsert ever falls back to insert).
          if (!result.containsKey(roomId) ||
              parsed.isAfter(result[roomId]!)) {
            result[roomId] = parsed;
          }
        }
      }
    }
    return result;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  DateTime _parseDate(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}
