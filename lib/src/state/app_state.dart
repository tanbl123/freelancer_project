import 'package:flutter/foundation.dart';

import '../backend/shared/domain_types.dart';
import '../features/applications/models/application_item.dart';
import '../features/marketplace/models/marketplace_post.dart';
import '../features/profile/models/profile_user.dart';
import '../features/ratings/models/review_item.dart';
import '../features/transactions/models/milestone_item.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal() {
    _loadSampleData();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  ProfileUser? _currentUser;
  ProfileUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  final List<ProfileUser> _users = [];
  List<ProfileUser> get users => List.unmodifiable(_users);

  // ── Data ──────────────────────────────────────────────────────────────────
  final List<MarketplacePost> _posts = [];
  final List<ApplicationItem> _applications = [];
  final List<MilestoneItem> _milestones = [];
  final List<ReviewItem> _reviews = [];

  List<MarketplacePost> get posts => List.unmodifiable(_posts);
  List<ApplicationItem> get applications => List.unmodifiable(_applications);
  List<MilestoneItem> get milestones => List.unmodifiable(_milestones);
  List<ReviewItem> get reviews => List.unmodifiable(_reviews);

  // ── Sample data ───────────────────────────────────────────────────────────
  void _loadSampleData() {
    _users.addAll([
      const ProfileUser(
        uid: 'client-1',
        displayName: 'Alicia Tan',
        role: 'client',
        bio: 'Looking for talented developers.',
        skills: [],
      ),
      const ProfileUser(
        uid: 'fr-1',
        displayName: 'Tan Boon Leong',
        role: 'freelancer',
        bio: 'Flutter & Firebase developer with 3 years of experience.',
        skills: ['Flutter', 'Firebase', 'Dart'],
      ),
    ]);

    _posts.addAll([
      MarketplacePost(
        id: 'post-1',
        ownerId: 'client-1',
        ownerName: 'Alicia Tan',
        title: 'Build responsive Flutter landing page',
        description: 'Need Flutter web layout + Firebase login integration.',
        minimumBudget: 450,
        deadline: DateTime.now().add(const Duration(days: 5)),
        skills: const ['Flutter', 'Firebase'],
        type: PostType.jobRequest,
      ),
      MarketplacePost(
        id: 'post-2',
        ownerId: 'fr-1',
        ownerName: 'Tan Boon Leong',
        title: 'UI/UX audit service',
        description: 'I provide UX audit reports with actionable fixes.',
        minimumBudget: 300,
        deadline: DateTime.now().add(const Duration(days: 10)),
        skills: const ['Figma', 'Research'],
        type: PostType.serviceOffering,
      ),
    ]);

    _applications.addAll([
      ApplicationItem(
        id: 'app-1',
        jobId: 'post-1',
        clientId: 'client-1',
        freelancerId: 'fr-1',
        freelancerName: 'Tan Boon Leong',
        proposalMessage: 'Can start immediately, 2 milestones, daily updates.',
        expectedBudget: 600,
        timelineDays: 7,
        status: ApplicationStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);

    _milestones.addAll([
      MilestoneItem(
        id: 'ms-1',
        projectId: 'project-1',
        title: 'Draft 1',
        description: 'Base UI and architecture setup',
        deadline: DateTime.now().add(const Duration(days: 2)),
        paymentAmount: 200,
        status: MilestoneStatus.submitted,
      ),
      MilestoneItem(
        id: 'ms-2',
        projectId: 'project-1',
        title: 'Final Delivery',
        description: 'Final polish and handover',
        deadline: DateTime.now().add(const Duration(days: 7)),
        paymentAmount: 400,
        status: MilestoneStatus.draft,
      ),
    ]);

    _reviews.addAll([
      const ReviewItem(
        id: 'r-1',
        projectId: 'project-1',
        reviewerId: 'client-1',
        freelancerId: 'fr-1',
        stars: 5,
        comment: 'Very responsive and delivered on schedule.',
      ),
    ]);
  }

  // ── Auth methods ──────────────────────────────────────────────────────────
  /// Returns null on success, error message on failure.
  String? login(String name) {
    if (name.trim().isEmpty) return 'Please enter your name.';
    final match = _users.where(
      (u) => u.displayName.toLowerCase() == name.trim().toLowerCase(),
    );
    if (match.isEmpty) return 'User "$name" not found. Register first.';
    _currentUser = match.first;
    notifyListeners();
    return null;
  }

  void register({
    required String name,
    required String role,
    String bio = '',
    List<String> skills = const [],
  }) {
    final uid = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final user = ProfileUser(
      uid: uid,
      displayName: name.trim(),
      role: role,
      bio: bio,
      skills: skills,
    );
    _users.add(user);
    _currentUser = user;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  void updateProfile(ProfileUser updated) {
    final idx = _users.indexWhere((u) => u.uid == updated.uid);
    if (idx >= 0) _users[idx] = updated;
    if (_currentUser?.uid == updated.uid) _currentUser = updated;
    notifyListeners();
  }

  // ── Marketplace ───────────────────────────────────────────────────────────
  void addPost(MarketplacePost post) {
    _posts.add(post);
    notifyListeners();
  }

  void deletePost(String postId) {
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  // ── Applications ──────────────────────────────────────────────────────────
  void addApplication(ApplicationItem app) {
    _applications.add(app);
    notifyListeners();
  }

  void updateApplicationStatus(String appId, ApplicationStatus status) {
    final idx = _applications.indexWhere((a) => a.id == appId);
    if (idx < 0) return;
    final old = _applications[idx];
    _applications[idx] = ApplicationItem(
      id: old.id,
      jobId: old.jobId,
      clientId: old.clientId,
      freelancerId: old.freelancerId,
      freelancerName: old.freelancerName,
      proposalMessage: old.proposalMessage,
      expectedBudget: old.expectedBudget,
      timelineDays: old.timelineDays,
      status: status,
      createdAt: old.createdAt,
    );
    notifyListeners();
  }

  // ── Milestones ────────────────────────────────────────────────────────────
  void addMilestone(MilestoneItem milestone) {
    _milestones.add(milestone);
    notifyListeners();
  }

  void updateMilestoneStatus(String milestoneId, MilestoneStatus status) {
    final idx = _milestones.indexWhere((m) => m.id == milestoneId);
    if (idx < 0) return;
    final old = _milestones[idx];
    _milestones[idx] = MilestoneItem(
      id: old.id,
      projectId: old.projectId,
      title: old.title,
      description: old.description,
      deadline: old.deadline,
      paymentAmount: old.paymentAmount,
      status: status,
    );
    notifyListeners();
  }

  // ── Reviews ───────────────────────────────────────────────────────────────
  void addReview(ReviewItem review) {
    _reviews.add(review);
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _newId => DateTime.now().millisecondsSinceEpoch.toString();
  String get newId => _newId;
}
