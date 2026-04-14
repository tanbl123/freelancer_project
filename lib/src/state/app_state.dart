import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../backend/shared/domain_types.dart';
import '../features/applications/models/application_item.dart';
import '../features/marketplace/models/marketplace_post.dart';
import '../features/profile/models/profile_user.dart';
import '../features/ratings/models/review_item.dart';
import '../features/transactions/models/milestone_item.dart';
import '../features/transactions/models/project_item.dart';
import '../services/database_service.dart';
import '../services/session_service.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal();

  static const _uuid = Uuid();
  final _db = DatabaseService.instance;
  final _session = SessionService.instance;

  // ── In-memory cache ────────────────────────────────────────────────────────
  ProfileUser? _currentUser;
  List<ProfileUser> _users = [];
  List<MarketplacePost> _posts = [];
  List<ApplicationItem> _applications = [];
  List<ProjectItem> _projects = [];
  List<MilestoneItem> _milestones = [];
  List<ReviewItem> _reviews = [];

  // ── Stream controllers (real-time UI feature) ──────────────────────────────
  final _postsController =
      StreamController<List<MarketplacePost>>.broadcast();
  final _appsController =
      StreamController<List<ApplicationItem>>.broadcast();

  Stream<List<MarketplacePost>> get postsStream => _postsController.stream;
  Stream<List<ApplicationItem>> get applicationsStream =>
      _appsController.stream;

  // ── Public getters ─────────────────────────────────────────────────────────
  ProfileUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  List<ProfileUser> get users => List.unmodifiable(_users);
  List<MarketplacePost> get posts => List.unmodifiable(_posts);
  List<ApplicationItem> get applications => List.unmodifiable(_applications);
  List<ProjectItem> get projects => List.unmodifiable(_projects);
  List<MilestoneItem> get milestones => List.unmodifiable(_milestones);
  List<ReviewItem> get reviews => List.unmodifiable(_reviews);

  String get newId => _uuid.v4();

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _users = await _db.getAllUsers();
    _posts = await _db.getActivePosts();
    _reviews = await _db.getAllReviews();

    final savedId = await _session.getSavedUserId();
    if (savedId != null) {
      _currentUser = await _db.getUserById(savedId);
      if (_currentUser != null) {
        await _reloadUserData();
      }
    }
    notifyListeners();
  }

  Future<void> _reloadUserData() async {
    if (_currentUser == null) return;
    _applications = await _db.getAllApplications();
    _projects = await _db.getProjectsForUser(_currentUser!.uid);
    _milestones = await _db.getMilestonesForProject(
        _projects.isNotEmpty ? _projects.first.id : '');
    _users = await _db.getAllUsers();
    _posts = await _db.getActivePosts();
    _reviews = await _db.getAllReviews();
  }

  // ── Password hashing ───────────────────────────────────────────────────────

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Returns null on success, error message on failure.
  Future<String?> login(String email, String password) async {
    final user = await _db.getUserByEmail(email.trim());
    if (user == null) return 'No account found for this email.';
    if (user.passwordHash != hashPassword(password)) {
      return 'Incorrect password.';
    }
    _currentUser = user;
    await _session.saveUserId(user.uid);
    await _reloadUserData();
    notifyListeners();
    return null;
  }

  /// Returns null on success, error message on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    String bio = '',
    String experience = '',
    List<String> skills = const [],
    String? photoUrl,
  }) async {
    if (name.trim().isEmpty) return 'Display name is required.';
    if (email.trim().isEmpty) return 'Email is required.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (phone.trim().isEmpty) return 'Phone number is required.';

    final existing = await _db.getUserByEmail(email.trim());
    if (existing != null) return 'This email is already registered.';

    final uid = _uuid.v4();
    final user = ProfileUser(
      uid: uid,
      displayName: name.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: hashPassword(password),
      phone: phone.trim(),
      role: role,
      bio: bio.trim().isEmpty ? null : bio.trim(),
      experience: experience.trim().isEmpty ? null : experience.trim(),
      skills: skills,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.insertUser(user);
    _users.add(user);
    _currentUser = user;
    await _session.saveUserId(uid);
    await _reloadUserData();
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _currentUser = null;
    _applications = [];
    _projects = [];
    _milestones = [];
    await _session.clearSession();
    notifyListeners();
  }

  Future<void> updateProfile(ProfileUser updated) async {
    await _db.updateUser(updated);
    final idx = _users.indexWhere((u) => u.uid == updated.uid);
    if (idx >= 0) _users[idx] = updated;
    if (_currentUser?.uid == updated.uid) _currentUser = updated;
    notifyListeners();
  }

  // ── Marketplace ────────────────────────────────────────────────────────────

  Future<void> addPost(MarketplacePost post) async {
    await _db.insertPost(post);
    _posts.insert(0, post);
    _postsController.add(List.unmodifiable(_posts));
    notifyListeners();
  }

  Future<void> updatePost(MarketplacePost post) async {
    await _db.updatePost(post);
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx >= 0) _posts[idx] = post;
    _postsController.add(List.unmodifiable(_posts));
    notifyListeners();
  }

  Future<void> deletePost(String postId) async {
    await _db.deletePost(postId);
    _posts.removeWhere((p) => p.id == postId);
    _postsController.add(List.unmodifiable(_posts));
    notifyListeners();
  }

  /// Reload posts from DB (e.g. after coming back online).
  Future<void> reloadPosts({bool useCache = false}) async {
    if (useCache) {
      _posts = await _db.getCachedJobs();
    } else {
      _posts = await _db.getActivePosts();
    }
    _postsController.add(List.unmodifiable(_posts));
    notifyListeners();
  }

  // ── Applications ───────────────────────────────────────────────────────────

  /// Returns null on success, error message on failure.
  Future<String?> addApplication(ApplicationItem app) async {
    // Business rules
    final duplicate = await _db.hasApplied(app.jobId, app.freelancerId);
    if (duplicate) return 'You already applied to this job.';

    final job = await _db.getPostById(app.jobId);
    if (job == null) return 'Job not found.';
    if (job.isExpired) return 'This job has expired and is no longer accepting applications.';
    if (job.isAccepted) return 'This job has already been filled.';

    await _db.insertApplication(app);
    _applications.insert(0, app);
    _appsController.add(List.unmodifiable(_applications));
    notifyListeners();
    return null;
  }

  Future<void> updateApplication(ApplicationItem app) async {
    await _db.updateApplication(app);
    final idx = _applications.indexWhere((a) => a.id == app.id);
    if (idx >= 0) _applications[idx] = app;
    _appsController.add(List.unmodifiable(_applications));
    notifyListeners();
  }

  Future<void> updateApplicationStatus(
      String appId, ApplicationStatus status) async {
    await _db.updateApplicationStatus(appId, status);
    final idx = _applications.indexWhere((a) => a.id == appId);
    if (idx >= 0) {
      _applications[idx] = _applications[idx].copyWith(status: status);
    }
    _appsController.add(List.unmodifiable(_applications));
    notifyListeners();
  }

  /// Accept an application: locks winner, rejects others, marks post accepted,
  /// auto-creates a project.
  Future<void> acceptApplication(ApplicationItem app) async {
    // 1. Accept the winner
    await _db.updateApplicationStatus(app.id, ApplicationStatus.accepted);
    // 2. Reject all other pending applications for the same job
    await _db.rejectAllOtherApplications(app.jobId, app.id);
    // 3. Mark post as accepted (removes from active feed)
    await _db.markPostAccepted(app.jobId);

    // 4. Auto-create project
    final projectId = _uuid.v4();
    final post = await _db.getPostById(app.jobId);
    final freelancer = await _db.getUserById(app.freelancerId);
    final client = await _db.getUserById(app.clientId);
    final project = ProjectItem(
      id: projectId,
      jobId: app.jobId,
      applicationId: app.id,
      clientId: app.clientId,
      freelancerId: app.freelancerId,
      status: 'inProgress',
      jobTitle: post?.title,
      clientName: client?.displayName,
      freelancerName: freelancer?.displayName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.insertProject(project);

    // 5. Reload everything
    await _reloadUserData();
    notifyListeners();
  }

  // ── Projects ───────────────────────────────────────────────────────────────

  Future<void> updateProjectStatus(String projectId, String status) async {
    await _db.updateProjectStatus(projectId, status);
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx >= 0) {
      _projects[idx] = _projects[idx].copyWith(status: status);
    }
    notifyListeners();
  }

  Future<List<MilestoneItem>> getMilestonesForProject(
      String projectId) async {
    return _db.getMilestonesForProject(projectId);
  }

  // ── Milestones ─────────────────────────────────────────────────────────────

  Future<void> addMilestone(MilestoneItem milestone) async {
    await _db.insertMilestone(milestone);
    _milestones.add(milestone);
    notifyListeners();
  }

  Future<void> updateMilestone(MilestoneItem milestone) async {
    await _db.updateMilestone(milestone);
    final idx = _milestones.indexWhere((m) => m.id == milestone.id);
    if (idx >= 0) _milestones[idx] = milestone;
    notifyListeners();
  }

  Future<void> updateMilestoneStatus(
      String milestoneId, MilestoneStatus status) async {
    await _db.updateMilestoneStatus(milestoneId, status);
    final idx = _milestones.indexWhere((m) => m.id == milestoneId);
    if (idx >= 0) {
      _milestones[idx] = _milestones[idx].copyWith(status: status);
    }
    notifyListeners();
  }

  Future<void> approveMilestone(
      String milestoneId, String signaturePath, String paymentToken) async {
    await _db.approveMilestone(milestoneId, signaturePath, paymentToken);
    final idx = _milestones.indexWhere((m) => m.id == milestoneId);
    if (idx >= 0) {
      _milestones[idx] = _milestones[idx].copyWith(
        status: MilestoneStatus.approved,
        clientSignatureUrl: signaturePath,
        paymentToken: paymentToken,
      );
    }
    notifyListeners();
  }

  Future<void> deleteMilestone(String milestoneId) async {
    await _db.deleteMilestone(milestoneId);
    _milestones.removeWhere((m) => m.id == milestoneId);
    notifyListeners();
  }

  // ── Reviews ────────────────────────────────────────────────────────────────

  /// Returns null on success, error message on failure.
  Future<String?> addReview(ReviewItem review) async {
    // Validate: must have a completed project between reviewer and freelancer
    final completedProject = await _db.getCompletedProjectBetween(
        review.reviewerId, review.freelancerId);
    if (completedProject == null) {
      return 'You can only review a freelancer after completing a project with them.';
    }
    // Prevent duplicate
    final alreadyReviewed =
        await _db.hasReviewedProject(review.projectId, review.reviewerId);
    if (alreadyReviewed) {
      return 'You have already submitted a review for this project.';
    }

    await _db.insertReview(review);
    _reviews.insert(0, review);
    // Recalculate freelancer stats
    await _db.updateFreelancerRatingStats(review.freelancerId);
    // Update in-memory user
    final updatedFreelancer = await _db.getUserById(review.freelancerId);
    if (updatedFreelancer != null) {
      final idx = _users.indexWhere((u) => u.uid == review.freelancerId);
      if (idx >= 0) _users[idx] = updatedFreelancer;
      if (_currentUser?.uid == review.freelancerId) {
        _currentUser = updatedFreelancer;
      }
    }
    notifyListeners();
    return null;
  }

  Future<void> updateReview(ReviewItem review) async {
    await _db.updateReview(review);
    final idx = _reviews.indexWhere((r) => r.id == review.id);
    if (idx >= 0) _reviews[idx] = review;
    await _db.updateFreelancerRatingStats(review.freelancerId);
    notifyListeners();
  }

  Future<void> deleteReview(String reviewId, String freelancerId) async {
    await _db.deleteReview(reviewId);
    _reviews.removeWhere((r) => r.id == reviewId);
    await _db.updateFreelancerRatingStats(freelancerId);
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Gets all freelancer users.
  List<ProfileUser> get freelancers =>
      _users.where((u) => u.role == 'freelancer').toList();

  /// Gets a completed project between the current user and a freelancer.
  Future<ProjectItem?> getCompletedProjectWith(String freelancerId) async {
    if (_currentUser == null) return null;
    return _db.getCompletedProjectBetween(_currentUser!.uid, freelancerId);
  }

  /// Gets projects for current user.
  List<ProjectItem> get userProjects {
    if (_currentUser == null) return [];
    return _projects
        .where((p) =>
            p.clientId == _currentUser!.uid ||
            p.freelancerId == _currentUser!.uid)
        .toList();
  }

  /// Gets applications visible to the current user.
  List<ApplicationItem> get userApplications {
    if (_currentUser == null) return [];
    if (_currentUser!.role == 'freelancer') {
      return _applications
          .where((a) => a.freelancerId == _currentUser!.uid)
          .toList();
    } else {
      return _applications
          .where((a) => a.clientId == _currentUser!.uid)
          .toList();
    }
  }

  /// Stats for charts.
  Future<Map<String, double>> getMonthlyEarnings(String freelancerId) =>
      _db.getMonthlyEarnings(freelancerId);

  Future<Map<int, int>> getRatingDistribution(String freelancerId) =>
      _db.getRatingDistribution(freelancerId);

  /// Reload all application data (called after returning to applications screen).
  Future<void> reloadApplications() async {
    _applications = await _db.getAllApplications();
    _appsController.add(List.unmodifiable(_applications));
    notifyListeners();
  }

  Future<void> reloadProjects() async {
    if (_currentUser == null) return;
    _projects = await _db.getProjectsForUser(_currentUser!.uid);
    notifyListeners();
  }
}
