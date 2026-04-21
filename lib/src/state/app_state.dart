import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../backend/shared/domain_types.dart';
import '../features/applications/models/application_item.dart';
import '../features/applications/models/service_order.dart';
import '../features/applications/repositories/application_repository.dart';
import '../features/applications/repositories/service_order_repository.dart';
import '../features/applications/services/service_order_service.dart';
import '../features/jobs/models/job_post.dart';
import '../features/transactions/repositories/milestone_repository.dart';
import '../features/transactions/repositories/project_repository.dart';
import '../features/transactions/services/milestone_service.dart';
import '../features/transactions/services/project_service.dart';
import '../features/jobs/repositories/job_post_repository.dart';
import '../features/jobs/services/job_post_service.dart';
import '../features/services/models/freelancer_service.dart';
import '../features/services/repositories/freelancer_service_repository.dart';
import '../features/services/services/freelancer_service_service.dart';
import '../features/marketplace/models/marketplace_post.dart';
import '../features/profile/models/profile_user.dart';
import '../features/profile/models/portfolio_item.dart';
import '../features/ratings/models/review_item.dart';
import '../features/ratings/repositories/review_repository.dart';
import '../features/ratings/services/review_service.dart';
import '../features/transactions/models/milestone_item.dart';
import '../features/transactions/models/project_item.dart';
import '../features/user/models/appeal.dart';
import '../features/user/models/freelancer_request.dart';
import '../features/user/repositories/appeal_repository.dart';
import '../features/user/repositories/freelancer_request_repository.dart';
import '../features/user/services/user_service.dart';
import '../features/chat/models/chat_message.dart';
import '../features/chat/models/chat_room.dart';
import '../features/chat/repositories/chat_repository.dart';
import '../features/chat/services/chat_service.dart';
import '../features/disputes/models/dispute_record.dart';
import '../features/disputes/repositories/dispute_repository.dart';
import '../features/disputes/services/dispute_service.dart';
import '../features/notifications/models/in_app_notification.dart';
import '../features/notifications/repositories/notification_repository.dart';
import '../features/notifications/services/notification_service.dart';
import '../shared/enums/notification_type.dart';
import '../features/overdue/models/overdue_record.dart';
import '../features/overdue/repositories/overdue_repository.dart';
import '../features/overdue/services/overdue_service.dart';
import '../features/payment/models/payment_record.dart';
import '../features/payment/models/payout_record.dart';
import '../features/payment/repositories/payment_repository.dart';
import '../features/payment/services/payment_service.dart';
import '../services/connectivity_service.dart';
import '../services/stripe_service.dart';
import '../services/supabase_service.dart';
import '../shared/models/category_item.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal();

  static const _uuid = Uuid();
  final _db = SupabaseService.instance;

  late final _requestRepo =
      FreelancerRequestRepository(SupabaseService.instance);
  late final _appealRepo = AppealRepository(SupabaseService.instance);
  late final _userService =
      UserService(SupabaseService.instance, _requestRepo, _appealRepo);
  late final _jobRepo = JobPostRepository(SupabaseService.instance);
  late final _jobService = JobPostService(_jobRepo);
  late final _serviceRepo =
      FreelancerServiceRepository(SupabaseService.instance);
  late final _serviceLogic = FreelancerServiceService(_serviceRepo);
  late final _appRepo   = ApplicationRepository(SupabaseService.instance);
  late final _orderRepo = ServiceOrderRepository(SupabaseService.instance);
  late final _orderService = ServiceOrderService(_orderRepo);
  late final _projectRepo = ProjectRepository(SupabaseService.instance);
  late final _milestoneRepo = MilestoneRepository(SupabaseService.instance);
  late final _projectSvc = ProjectService(_projectRepo);
  late final _milestoneSvc =
      MilestoneService(_milestoneRepo, _projectRepo);
  late final _paymentRepo = PaymentRepository(SupabaseService.instance);
  late final _paymentSvc = PaymentService(_paymentRepo);
  late final _overdueRepo = OverdueRepository(SupabaseService.instance);
  late final _overdueSvc = OverdueService(_overdueRepo);
  late final _notifRepo = NotificationRepository(SupabaseService.instance);
  late final _notifSvc = NotificationService(_notifRepo);
  late final _disputeRepo = DisputeRepository(SupabaseService.instance);
  late final _disputeSvc =
      DisputeService(_disputeRepo, _projectRepo, _paymentRepo);
  late final _chatRepo = ChatRepository(SupabaseService.instance);
  late final _chatSvc = ChatService(_chatRepo);
  late final _reviewRepo = ReviewRepository(SupabaseService.instance);
  late final _reviewSvc = ReviewService(_reviewRepo);

  // ── In-memory cache ────────────────────────────────────────────────────────
  ProfileUser? _currentUser;
  List<ProfileUser> _users = [];
  List<MarketplacePost> _posts = [];
  List<ApplicationItem> _applications = [];
  List<ProjectItem> _projects = [];
  List<MilestoneItem> _milestones = [];
  List<ReviewItem> _reviews = [];
  List<ReviewItem> _reportedReviews = [];

  // Portfolio items (freelancer profile)
  List<PortfolioItem> _portfolioItems = [];

  // Job Posting Module state
  List<JobPost> _jobPosts        = [];    // open posts visible in the feed
  List<JobPost> _myJobPosts      = [];    // all posts owned by the current client
  bool _jobPostsFromCache        = false; // true when feed is from SQLite
  bool _isOnline                 = true;  // last-known connectivity status
  DateTime? _jobCacheLastSyncedAt;        // when the cache was last written
  StreamSubscription<bool>? _connectivitySub;           // reconnect watcher
  StreamSubscription<List<InAppNotification>>? _notifSub; // realtime notifs

  // Categories (loaded from DB, replaces JobCategory enum)
  List<CategoryItem> _categories = [];

  // Provide Service Module state
  List<FreelancerService> _services = [];    // active services in the feed
  List<FreelancerService> _myServices = [];  // freelancer's own (non-deleted) services
  bool _servicesFromCache = false;           // true when feed loaded from SQLite

  // Request & Application Module — Service Orders
  List<ServiceOrder> _serviceOrders = [];    // current user's service orders

  /// Guards acceptApplication / acceptOrder against double-tap duplicate calls.
  final Set<String> _acceptingIds = {};

  // Payment Module state
  /// Payment record for the project currently being viewed.
  PaymentRecord? _currentPaymentRecord;
  PaymentRecord? get currentPaymentRecord => _currentPaymentRecord;

  // User module state
  FreelancerRequest? _myFreelancerRequest;
  List<Appeal> _myAppeals = [];
  List<FreelancerRequest> _allFreelancerRequests = []; // admin only
  List<Appeal> _allAppeals = [];                        // admin only

  // Overdue & Notification Module state
  List<InAppNotification> _notifications = [];
  Timer? _overdueTimer;

  // Dispute Module state
  DisputeRecord? _activeDispute;
  List<DisputeRecord> _allOpenDisputes = []; // admin only

  // Chat Module state
  List<ChatRoom> _chatRooms = [];
  Map<String, bool> _chatUnreadMap = {}; // roomId → has unread
  Map<String, String> _chatUserNames = {}; // uid → displayName (for room titles)

  List<InAppNotification> get notifications =>
      List.unmodifiable(_notifications);
  // Chat messages have their own unread dot (unreadChatCount).
  // Exclude them from the bell badge to avoid double-counting.
  int get unreadNotificationCount => _notifications
      .where((n) => !n.isRead && n.type != NotificationType.newChatMessage)
      .length;

  // Dispute getters
  DisputeRecord? get activeDispute => _activeDispute;
  List<DisputeRecord> get allOpenDisputes =>
      List.unmodifiable(_allOpenDisputes);

  // Chat getters
  List<ChatRoom> get chatRooms => List.unmodifiable(_chatRooms);
  int get unreadChatCount =>
      _chatUnreadMap.values.where((v) => v).length;
  bool hasUnreadInRoom(String roomId) => _chatUnreadMap[roomId] ?? false;
  /// uid → display name cache for chat room participants.
  Map<String, String> get chatUserNames => Map.unmodifiable(_chatUserNames);

  /// Combined badge count: unread notifications + unread chat rooms.
  int get totalUnreadCount => unreadNotificationCount + unreadChatCount;

  ChatService get chatService => _chatSvc;
  ReviewService get reviewService => _reviewSvc;

  // ── Supabase Realtime streams ──────────────────────────────────────────────
  Stream<List<MarketplacePost>> get postsStream =>
      Supabase.instance.client.from('posts').stream(primaryKey: ['id']).order(
          'created_at',
          ascending: false).map((rows) =>
          rows.map(MarketplacePost.fromMap).toList());

  /// **Role-scoped** realtime stream of job applications.
  ///
  /// - Client → filters by `client_id` (applications to jobs they posted).
  /// - Freelancer → filters by `freelancer_id` (proposals they submitted).
  ///
  /// Previously this stream had **no filter** and returned every application
  /// in the database. Now it delegates to [ApplicationRepository] which
  /// applies the correct single-column `.eq()` filter supported by Supabase
  /// Realtime `.stream()`.
  Stream<List<ApplicationItem>> get applicationsStream {
    final uid = _currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _currentUser!.role == UserRole.freelancer
        ? _appRepo.streamForFreelancer(uid)
        : _appRepo.streamForClient(uid);
  }

  // ── Public getters ─────────────────────────────────────────────────────────
  ProfileUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Reloads the current user's profile from the DB and notifies listeners.
  Future<void> reloadCurrentUser() async {
    if (_currentUser == null) return;
    final updated = await _db.getUserById(_currentUser!.uid);
    if (updated != null) {
      _currentUser = updated;
      notifyListeners();
    }
  }
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isFreelancer => _currentUser?.role == UserRole.freelancer;
  bool get needsEmailVerification =>
      _currentUser?.accountStatus == AccountStatus.pendingVerification;
  bool get isRestricted =>
      _currentUser?.accountStatus == AccountStatus.restricted;

  List<CategoryItem> get categories => List.unmodifiable(_categories);

  List<ProfileUser> get users => List.unmodifiable(_users);
  List<MarketplacePost> get posts => List.unmodifiable(_posts);
  List<ApplicationItem> get applications => List.unmodifiable(_applications);
  List<ProjectItem> get projects => List.unmodifiable(_projects);
  List<MilestoneItem> get milestones => List.unmodifiable(_milestones);
  List<ReviewItem> get reviews => List.unmodifiable(_reviews);
  List<ReviewItem> get reportedReviews => List.unmodifiable(_reportedReviews);
  List<PortfolioItem> get portfolioItems => List.unmodifiable(_portfolioItems);

  // ── Reviews computed helpers ───────────────────────────────────────────────

  /// Reviews received by the current user (published only).
  List<ReviewItem> get myReceivedReviews {
    final uid = _currentUser?.uid;
    if (uid == null) return [];
    return _reviews
        .where((r) => r.revieweeId == uid && r.isVisible)
        .toList();
  }

  /// Reviews written by the current user.
  List<ReviewItem> get myGivenReviews {
    final uid = _currentUser?.uid;
    if (uid == null) return [];
    return _reviews.where((r) => r.reviewerId == uid).toList();
  }

  /// Completed projects where the current user has not yet written a review.
  List<ProjectItem> get eligibleReviewProjects {
    final uid = _currentUser?.uid;
    if (uid == null) return [];
    final reviewedIds =
        _reviews.where((r) => r.reviewerId == uid).map((r) => r.projectId).toSet();
    return userProjects
        .where((p) => p.isCompleted && !reviewedIds.contains(p.id))
        .toList();
  }

  // ── Job Posts ──────────────────────────────────────────────────────────────
  List<JobPost> get jobPosts           => List.unmodifiable(_jobPosts);
  List<JobPost> get myJobPosts         => List.unmodifiable(_myJobPosts);
  bool          get jobPostsFromCache  => _jobPostsFromCache;
  bool          get isOnline           => _isOnline;
  DateTime?     get jobCacheLastSyncedAt => _jobCacheLastSyncedAt;

  // ── Freelancer Services ────────────────────────────────────────────────────
  List<FreelancerService> get services => List.unmodifiable(_services);
  List<FreelancerService> get myServices => List.unmodifiable(_myServices);
  bool get servicesFromCache => _servicesFromCache;

  // ── Service Orders ─────────────────────────────────────────────────────────
  List<ServiceOrder> get serviceOrders => List.unmodifiable(_serviceOrders);

  /// Realtime stream of active service listings.
  Stream<List<FreelancerService>> get servicesStream =>
      Supabase.instance.client
          .from('freelancer_services')
          .stream(primaryKey: ['id'])
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .map((rows) => rows.map(FreelancerService.fromMap).toList());

  /// **Role-scoped** realtime stream of service orders.
  ///
  /// - Freelancer → orders received for their services.
  /// - Client → orders they placed.
  ///
  /// Delegates to [ServiceOrderRepository] so stream logic stays in the
  /// data layer and can be tested independently.
  Stream<List<ServiceOrder>> get serviceOrdersStream {
    final uid = _currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _currentUser!.role == UserRole.freelancer
        ? _orderRepo.streamForFreelancer(uid)
        : _orderRepo.streamForClient(uid);
  }

  /// Realtime stream for open job posts (Supabase Realtime channel).
  Stream<List<JobPost>> get jobPostsStream =>
      Supabase.instance.client
          .from('job_posts')
          .stream(primaryKey: ['id'])
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .map((rows) => rows.map(JobPost.fromMap).toList());

  FreelancerRequest? get myFreelancerRequest => _myFreelancerRequest;
  List<Appeal> get myAppeals => List.unmodifiable(_myAppeals);
  List<FreelancerRequest> get allFreelancerRequests =>
      List.unmodifiable(_allFreelancerRequests);
  List<Appeal> get allAppeals => List.unmodifiable(_allAppeals);

  String get newId => _uuid.v4();

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _users = await _db.getAllUsers();
    _posts = await _db.getActivePosts();
    _reviews = await _db.getAllReviews();
    _categories = await _db.fetchCategories();

    // Restore session from Supabase Auth
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _currentUser = await _db.getUserById(session.user.id);
      if (_currentUser != null) {
        await _reloadUserData();
      }
    }
    notifyListeners();

    // Listen for auth state changes (OAuth sign-in, token refresh, sign-out).
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        final provider =
            session.user.appMetadata['provider'] as String? ?? '';

        if (provider == 'google') {
          // ── Google OAuth ──────────────────────────────────────────────────
          // Email is already verified by Google; create/load profile as active.
          final profile =
              await _userService.ensureGoogleProfile(session.user);
          _currentUser = profile;
          await _reloadUserData();
          notifyListeners();
        } else {
          // ── Email / password ──────────────────────────────────────────────
          // The handle_new_user() DB trigger creates a skeleton profile with
          // pendingVerification the instant signUp() is called — before the
          // user has entered their OTP.  If we load that skeleton here and set
          // _currentUser, the router redirects to EmailVerificationScreen right
          // in the middle of verifySignupOtp(), creating a race condition.
          //
          // Rule: ignore pendingVerification profiles in this listener.
          // verifySignupOtp() upserts the full active profile and sets
          // _currentUser itself once the OTP is confirmed.
          // For normal logins (existing active/restricted users) the profile
          // will NOT be pendingVerification, so this guard has no effect.
          final profile = await _db.getUserById(session.user.id);
          if (profile != null &&
              _currentUser == null &&
              profile.accountStatus != AccountStatus.pendingVerification) {
            _currentUser = profile;
            await _reloadUserData();
            notifyListeners();
          }
        }
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        // Keep local profile in sync when the session token is silently renewed.
        if (_currentUser == null) {
          _currentUser = await _db.getUserById(session.user.id);
          if (_currentUser != null) {
            await _reloadUserData();
            notifyListeners();
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _clearLocalState();
        notifyListeners();
      }
    });

    // NOTE: Deep link / OAuth callback handling (io.supabase.freelancerapp://
    // login-callback?code=...) is done automatically by the supabase_flutter
    // package via its internal app_links listener.  We must NOT call
    // getSessionFromUrl() ourselves — doing so consumes the one-time PKCE
    // code a second time, which causes Supabase to sign the user out.
    // The onAuthStateChange listener above is all that is needed on our side.
  }

  Future<void> _reloadUserData() async {
    if (_currentUser == null) return;
    // Fetch only applications relevant to this user's role, not all DB rows.
    _applications = _currentUser!.role == UserRole.freelancer
        ? await _appRepo.getByFreelancer(_currentUser!.uid)
        : await _appRepo.getByClient(_currentUser!.uid);
    _projects = await _db.getProjectsForUser(_currentUser!.uid);
    // Only load milestones when there are projects — never pass an empty UUID.
    _milestones = [];
    _users = await _db.getAllUsers();
    _posts = await _db.getActivePosts();
    _reviews = await _db.getAllReviews();

    // Load job posts (offline-first) and start connectivity watcher.
    await _loadJobPostsFeed();
    _startConnectivityWatcher();
    if (_currentUser!.role == UserRole.client) {
      _myJobPosts =
          await _jobRepo.getPostsByClient(_currentUser!.uid);
    }

    // Load service listings (offline-first)
    await _loadServicesFeed();
    if (_currentUser!.role == UserRole.freelancer) {
      _myServices =
          await _serviceRepo.getServicesByFreelancer(_currentUser!.uid);
    }

    // Load service orders for both clients (sent) and freelancers (received).
    await _loadServiceOrders();

    // Load user-module state
    _myFreelancerRequest =
        await _requestRepo.getLatest(_currentUser!.uid);
    _myAppeals = await _appealRepo.getForUser(_currentUser!.uid);

    // Admin: load all requests and appeals
    if (_currentUser!.role == UserRole.admin) {
      _allFreelancerRequests =
          await _requestRepo.getAll(status: RequestStatus.pending);
      _allAppeals =
          await _appealRepo.getAll(status: AppealStatus.open);
    }

    // Chat rooms (load for all users)
    await loadChatRooms();

    // Start realtime notification stream so the badge and inbox update
    // automatically whenever any user sends a notification to this user.
    _startNotificationsStream();
  }

  void _clearLocalState() {
    _currentUser = null;
    _posts = [];
    _applications = [];
    _projects = [];
    _milestones = [];
    _reviews = [];
    _jobPosts              = [];
    _myJobPosts            = [];
    _jobPostsFromCache     = false;
    _isOnline              = true;
    _jobCacheLastSyncedAt  = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _notifSub?.cancel();
    _notifSub = null;
    _notifications = [];
    _services = [];
    _myServices = [];
    _servicesFromCache = false;
    _serviceOrders = [];
    _myFreelancerRequest = null;
    _myAppeals = [];
    _allFreelancerRequests = [];
    _allAppeals = [];
    _activeDispute = null;
    _allOpenDisputes = [];
    _chatRooms = [];
    _chatUnreadMap = {};
    _reportedReviews = [];
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Returns null on success, error message on failure.
  Future<String?> login(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
                'Connection timed out. Check your internet or try again.'),
          );
      if (response.user == null) return 'Login failed. Please try again.';

      _currentUser = await _db.getUserById(response.user!.id);
      if (_currentUser == null) {
        await Supabase.instance.client.auth.signOut().catchError((_) {});
        return 'Account not found. Please contact support.';
      }

      final status = _currentUser!.accountStatus;
      if (status == AccountStatus.deactivated) {
        await Supabase.instance.client.auth.signOut().catchError((_) {});
        _currentUser = null;
        return 'This account has been deactivated. Please contact support.';
      }
      // pendingVerification and restricted are allowed to log in.

      await _reloadUserData();
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  /// Google / OAuth sign-in. Opens the provider's browser flow.
  /// Profile creation on first sign-in is handled by the auth state listener.
  Future<String?> signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.freelancerapp://login-callback',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Google sign-in failed: $e';
    }
  }

  /// Returns null on success, error message on failure.
  /// New users always start as Client with PendingVerification status.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? photoUrl,
  }) async {
    return _userService.register(
      name: name,
      email: email,
      password: password,
      phone: phone,
      photoUrl: photoUrl,
    );
  }

  /// Resend the OTP verification email.
  /// [overrideEmail] lets callers pass the email directly when _currentUser
  /// is not yet set (e.g. right after signUp fires but before the auth
  /// state listener has populated _currentUser).
  Future<String?> resendVerificationEmail({String? overrideEmail}) async {
    final email = overrideEmail ??
        _currentUser?.email ??
        Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) return 'No user logged in.';
    try {
      await Supabase.instance.client.auth
          .resend(type: OtpType.signup, email: email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to resend email: $e';
    }
  }

  /// Verifies the 6-digit OTP sent to the user's email during sign-up.
  ///
  /// After verifyOTP the user has a confirmed auth session, so we can
  /// safely INSERT the profile row (RLS requires auth.uid() = id).
  /// Returns null on success, or an error message string on failure.
  Future<String?> verifySignupOtp({
    required String email,
    required String token,
    required String name,
    required String phone,
    String? photoUrl,
  }) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      // User now has a confirmed, authenticated session.
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) return 'Verification failed. Please try again.';

      // Create the profile row now that RLS will allow it.
      final profile = ProfileUser(
        uid: authUser.id,
        displayName: name.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        role: UserRole.client,
        accountStatus: AccountStatus.active, // email confirmed → active
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _db.insertUser(profile);
      _currentUser = profile;
      await _reloadUserData();
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Verification failed: $e';
    }
  }

  /// Cancels an incomplete registration (user tapped Back on the OTP screen).
  ///
  /// With the OTP flow the profile row is NOT created until after OTP
  /// verification, so there is nothing to delete from the profiles table.
  /// We just sign out from Supabase Auth and clear local state so the user
  /// lands back on RegisterPage with a clean slate.
  ///
  /// The auth.users record is left in Supabase (client cannot delete it),
  /// but without a profile row the account is effectively abandoned.
  /// If the same email is used again, signUp re-sends a fresh OTP and
  /// insertUser will create the profile cleanly after verification.
  Future<void> cancelRegistration() async {
    _stopOverdueChecker();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    _clearLocalState();
    notifyListeners();
  }

  /// Checks whether the current user's email is confirmed in Supabase Auth.
  /// If confirmed, updates accountStatus to Active in the profiles table.
  Future<bool> checkEmailVerified() async {
    if (_currentUser == null) return false;
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser?.emailConfirmedAt != null) {
      final updated = _currentUser!.copyWith(
        accountStatus: AccountStatus.active,
      );
      await _db.updateUser(updated);
      _currentUser = updated;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Sends a password-reset OTP to [email].
  /// Returns null on success, or an error message on failure.
  Future<String?> sendPasswordResetOtp(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to send reset email: $e';
    }
  }

  /// Step 2 — Verifies the recovery OTP and opens an authenticated session.
  /// Returns null on success, or an error message on failure.
  /// Call [updatePasswordAfterReset] next to set the new password.
  Future<String?> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token,
        type: OtpType.recovery,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'OTP verification failed: $e';
    }
  }

  /// Step 3 — Sets the new password after OTP has been verified.
  /// Signs the user out afterwards so they must log in with the new password.
  /// Returns null on success, or an error message on failure.
  Future<String?> updatePasswordAfterReset(String newPassword) async {
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPassword));
      // Sign out so the user is prompted to log in with the new password.
      await Supabase.instance.client.auth.signOut();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Password reset failed: $e';
    }
  }

  Future<void> logout() async {
    _stopOverdueChecker();
    _connectivitySub?.cancel();
    _connectivitySub = null;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Network failure is non-fatal — local state cleared below.
    }
    // Wipe the job cache so the next user starts with a clean slate.
    await _jobRepo.clearCache().catchError((_) {});
    _clearLocalState();
    notifyListeners();
  }

  /// Self-initiated soft deactivation. Keeps the row for audit trail.
  ///
  /// **Guards:**
  /// - Freelancers with any ongoing project (`pendingStart` or `inProgress`)
  ///   are blocked until they complete or cancel all active work.
  ///
  /// **Side-effects on success:**
  /// - Freelancer: all active services → inactive; pending applications → withdrawn.
  /// - Client: all open job posts → closed.
  Future<String?> deleteAccount() async {
    try {
      final uid = _currentUser?.uid;
      if (uid == null) return 'Not logged in.';
      final role = _currentUser!.role;

      // ── Guard: block freelancers with active projects ──────────────────────
      if (role == UserRole.freelancer) {
        final hasActiveWork = _projects.any((p) =>
            p.freelancerId == uid &&
            (p.status == ProjectStatus.pendingStart ||
                p.status == ProjectStatus.inProgress ||
                p.status == ProjectStatus.disputed));
        if (hasActiveWork) {
          return 'You have ongoing projects. Please complete or cancel all '
              'active projects before deactivating your account.';
        }
      }

      // ── Guard: block clients with active projects ──────────────────────────
      if (role == UserRole.client) {
        final hasActiveWork = _projects.any((p) =>
            p.clientId == uid &&
            (p.status == ProjectStatus.pendingStart ||
                p.status == ProjectStatus.inProgress ||
                p.status == ProjectStatus.disputed));
        if (hasActiveWork) {
          return 'You have ongoing projects. Please complete or wait for all '
              'active projects to finish before deactivating your account.';
        }
      }

      // ── Hide content from browse feeds ────────────────────────────────────
      await _db.deactivateUserContent(uid, role);

      // ── Deactivate the profile row ────────────────────────────────────────
      await _db.deactivateUser(uid);

      // ── Update in-memory state so UI responds immediately ─────────────────
      if (role == UserRole.freelancer) {
        // Mark services inactive locally
        _myServices = _myServices
            .map((s) => s.status == ServiceStatus.active
                ? s.copyWith(status: ServiceStatus.inactive)
                : s)
            .toList();
        // Remove withdrawn pending applications from the local list
        _applications.removeWhere(
            (a) => a.freelancerId == uid && a.status == ApplicationStatus.pending);
      } else if (role == UserRole.client) {
        // Mark open job posts closed locally
        _myJobPosts = _myJobPosts
            .map((p) => p.status == JobStatus.open
                ? p.copyWith(status: JobStatus.closed)
                : p)
            .toList();
      }

      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      _clearLocalState();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to deactivate account: $e';
    }
  }

  Future<void> updateProfile(ProfileUser updated) async {
    await _db.updateUser(updated);

    // ── Propagate display name change everywhere it is denormalized ──────────
    final oldName = _currentUser?.displayName;
    final newName = updated.displayName;
    if (oldName != null && oldName != newName) {
      final uid = updated.uid;

      // Update Supabase (all 11 tables) — awaited so we know if it failed.
      // Previously this was fire-and-forget (.catchError((_) {})) which silently
      // left Supabase with the old name on any network error.
      try {
        await _db.updateUserDisplayNameEverywhere(uid, newName);
      } catch (e) {
        debugPrint('[updateProfile] cascade rename failed: $e');
        // Non-fatal — in-memory and SQLite cache are still updated below;
        // the Supabase rows will be corrected on the next successful edit.
      }

      // Patch the local SQLite job-post cache so the offline Browse tab
      // never serves the stale old name.
      try {
        await _db.updateCachedClientName(uid, newName);
      } catch (e) {
        debugPrint('[updateProfile] SQLite cache rename failed: $e');
      }

      // Mirror the rename in every in-memory list immediately so the UI
      // updates without waiting for a full reload.

      // Job posts (client_name)
      for (final list in [_jobPosts, _myJobPosts]) {
        for (int i = 0; i < list.length; i++) {
          if (list[i].clientId == uid) {
            list[i] = list[i].copyWith(clientName: newName);
          }
        }
      }

      // Freelancer services (freelancer_name)
      for (final list in [_services, _myServices]) {
        for (int i = 0; i < list.length; i++) {
          if (list[i].freelancerId == uid) {
            list[i] = list[i].copyWith(freelancerName: newName);
          }
        }
      }

      // Applications (freelancer_name)
      for (int i = 0; i < _applications.length; i++) {
        if (_applications[i].freelancerId == uid) {
          _applications[i] = _applications[i].copyWith(freelancerName: newName);
        }
      }

      // Service orders (both sides)
      for (int i = 0; i < _serviceOrders.length; i++) {
        final o = _serviceOrders[i];
        if (o.freelancerId == uid) {
          _serviceOrders[i] = o.copyWith(freelancerName: newName);
        } else if (o.clientId == uid) {
          _serviceOrders[i] = o.copyWith(clientName: newName);
        }
      }

      // Projects (both sides)
      for (int i = 0; i < _projects.length; i++) {
        final p = _projects[i];
        if (p.freelancerId == uid) {
          _projects[i] = p.copyWith(freelancerName: newName);
        } else if (p.clientId == uid) {
          _projects[i] = p.copyWith(clientName: newName);
        }
      }

      // Legacy marketplace posts (owner_name)
      for (int i = 0; i < _posts.length; i++) {
        if (_posts[i].ownerId == uid) {
          _posts[i] = _posts[i].copyWith(ownerName: newName);
        }
      }
    }

    final idx = _users.indexWhere((u) => u.uid == updated.uid);
    if (idx >= 0) _users[idx] = updated;
    if (_currentUser?.uid == updated.uid) _currentUser = updated;
    notifyListeners();
  }

  Future<String?> changePassword(String newPassword) async {
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPassword));
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to update password: $e';
    }
  }

  // ── User Module ────────────────────────────────────────────────────────────

  /// Client submits a request to upgrade to freelancer role.
  Future<String?> submitFreelancerRequest(
      String message, String? portfolioUrl) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _userService.submitFreelancerRequest(
        _currentUser!, message, portfolioUrl);
    if (error == null) {
      _myFreelancerRequest = await _requestRepo.getLatest(_currentUser!.uid);
      notifyListeners();
    }
    return error;
  }

  /// Admin: approve a freelancer request.
  Future<String?> approveFreelancerRequest(String requestId) async {
    if (!isAdmin) return 'Access denied.';
    // Capture the requesterId before the operation so we can notify them.
    final request = _allFreelancerRequests
        .cast<FreelancerRequest?>()
        .firstWhere((r) => r?.id == requestId, orElse: () => null);
    final error = await _userService.approveFreelancerRequest(
        requestId, _currentUser!.uid);
    if (error == null) {
      if (request != null) {
        try {
          await _notifSvc.send(NotificationService.makeFreelancerRequestApproved(
            userId: request.requesterId,
          ));
        } catch (_) {}
      }
      await _reloadAdminData();
      notifyListeners();
    }
    return error;
  }

  /// Admin: reject a freelancer request.
  Future<String?> rejectFreelancerRequest(
      String requestId, String note) async {
    if (!isAdmin) return 'Access denied.';
    // Capture the requesterId before the operation so we can notify them.
    final request = _allFreelancerRequests
        .cast<FreelancerRequest?>()
        .firstWhere((r) => r?.id == requestId, orElse: () => null);
    final error = await _userService.rejectFreelancerRequest(
        requestId, _currentUser!.uid, note);
    if (error == null) {
      if (request != null) {
        try {
          await _notifSvc.send(NotificationService.makeFreelancerRequestRejected(
            userId: request.requesterId,
            note: note,
          ));
        } catch (_) {}
      }
      await _reloadAdminData();
      notifyListeners();
    }
    return error;
  }

  /// Restricted/deactivated user submits an appeal.
  Future<String?> submitAppeal(
      String reason, List<String> evidenceUrls) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _userService.submitAppeal(
        _currentUser!, reason, evidenceUrls);
    if (error == null) {
      _myAppeals = await _appealRepo.getForUser(_currentUser!.uid);
      notifyListeners();
    }
    return error;
  }

  /// Admin: resolve an appeal (approve or reject).
  Future<String?> resolveAppeal(
    String appealId,
    AppealStatus resolution,
    String appellantId,
    String response,
  ) async {
    if (!isAdmin) return 'Access denied.';
    final error = await _userService.resolveAppeal(
        appealId, resolution, _currentUser!.uid, response, appellantId);
    if (error == null) {
      await _reloadAdminData();
      // If appellant is in the user list, refresh their profile
      final idx = _users.indexWhere((u) => u.uid == appellantId);
      if (idx >= 0) {
        final updated = await _db.getUserById(appellantId);
        if (updated != null) _users[idx] = updated;
      }
      notifyListeners();
    }
    return error;
  }

  /// Admin: change any user's account status.
  Future<String?> setAccountStatus(
      String userId, AccountStatus status) async {
    if (!isAdmin) return 'Access denied.';
    final error =
        await _userService.setAccountStatus(userId, status, _currentUser!.uid);
    if (error == null) {
      final idx = _users.indexWhere((u) => u.uid == userId);
      if (idx >= 0) {
        final updated = await _db.getUserById(userId);
        if (updated != null) _users[idx] = updated;
      }
      notifyListeners();
    }
    return error;
  }

  Future<void> _reloadAdminData() async {
    _allFreelancerRequests =
        await _requestRepo.getAll(); // fetch all statuses so tabs stay current
    _allAppeals = await _appealRepo.getAll(status: AppealStatus.open);
    _allOpenDisputes = await _disputeRepo.getAllOpen();
    _reportedReviews = await _reviewSvc.getReported();
    _users = await _db.getAllUsers();
  }

  Future<void> loadAllFreelancerRequests() async {
    if (!isAdmin) return;
    _allFreelancerRequests = await _requestRepo.getAll();
    notifyListeners();
  }

  Future<void> loadAllAppeals() async {
    if (!isAdmin) return;
    _allAppeals = await _appealRepo.getAll();
    notifyListeners();
  }

  // ── Job Posts ──────────────────────────────────────────────────────────────

  /// Offline-first feed loader used at startup and on reconnect.
  ///
  /// Decision tree:
  /// 1. Check connectivity via [ConnectivityService] — explicit, not guessed.
  /// 2. **Offline** → serve SQLite immediately, no network attempt.
  /// 3. **Online** → fetch Supabase → write columnar cache → clear offline flag.
  /// 4. **Online but Supabase fails** → fall back to SQLite and mark offline.
  /// Cross-references [posts] against the in-memory [_users] list and fixes
  /// any job post whose `clientName` no longer matches the owner's current
  /// `displayName` (i.e. the user renamed after posting).
  ///
  /// Returns a corrected list.  For each stale entry, a background write
  /// repairs both Supabase and the local SQLite cache so future loads are
  /// already correct.
  List<JobPost> _healJobPostNames(List<JobPost> posts) {
    if (_users.isEmpty) return posts; // users not yet loaded — skip

    final Map<String, String> fixes = {}; // clientId → correct name

    final healed = posts.map((post) {
      final knownUser =
          _users.where((u) => u.uid == post.clientId).firstOrNull;
      if (knownUser != null && knownUser.displayName != post.clientName) {
        fixes[post.clientId] = knownUser.displayName;
        return post.copyWith(clientName: knownUser.displayName);
      }
      return post;
    }).toList();

    // Repair Supabase + SQLite cache in the background for every stale owner.
    for (final entry in fixes.entries) {
      _db.updateUserDisplayNameEverywhere(entry.key, entry.value)
          .catchError((e) => debugPrint(
              '[healJobPostNames] Supabase fix failed for ${entry.key}: $e'));
      _db.updateCachedClientName(entry.key, entry.value)
          .catchError((e) => debugPrint(
              '[healJobPostNames] cache fix failed for ${entry.key}: $e'));
    }

    return healed;
  }

  Future<void> _loadJobPostsFeed() async {
    _isOnline = await ConnectivityService.instance.isOnline();

    if (!_isOnline) {
      // Fast path — skip network entirely.
      await _loadFromCache();
      return;
    }

    try {
      final raw = await _jobRepo.getOpenPosts();
      final fresh = _healJobPostNames(raw); // fix any stale client names
      _jobPosts             = fresh;
      _jobPostsFromCache    = false;
      // Write to columnar cache; record last-synced timestamp.
      if (fresh.isNotEmpty) {
        await _jobRepo.cache(fresh);
        _jobCacheLastSyncedAt = DateTime.now();
      }
    } catch (_) {
      // Supabase reachable but request failed (RLS, timeout, etc.) —
      // treat the same as offline so the user still sees data.
      _isOnline = false;
      await _loadFromCache();
    }
  }

  /// Loads the SQLite cache into [_jobPosts] and updates [_jobCacheLastSyncedAt].
  Future<void> _loadFromCache() async {
    _jobPosts             = await _jobRepo.getCached();
    _jobPostsFromCache    = _jobPosts.isNotEmpty;
    _jobCacheLastSyncedAt = await _jobRepo.getCacheLastSyncedAt();
  }

  /// Connectivity watcher — subscribes once per session.
  ///
  /// When the device moves from offline → online, automatically re-fetches
  /// the job feed so the user never has to manually pull-to-refresh after
  /// re-connecting.
  void _startConnectivityWatcher() {
    _connectivitySub?.cancel(); // guard against double-subscribe
    _connectivitySub = ConnectivityService.instance.onlineStream.listen(
      (online) async {
        final wasOffline = !_isOnline;
        _isOnline = online;

        if (online && wasOffline) {
          // Just came back online — silently re-fetch.
          await _loadJobPostsFeed();
        }
        // Always notify so the banner appears/disappears promptly.
        notifyListeners();
      },
    );
  }

  /// Public reload — called by pull-to-refresh and filter changes.
  ///
  /// Filtered results are *not* written to cache because the cache is
  /// intended to represent the unfiltered "latest 20 open jobs" baseline.
  Future<void> reloadJobPosts({
    String? search,
    String? category,
    double? minBudget,
    double? maxBudget,
  }) async {
    _isOnline = await ConnectivityService.instance.isOnline();

    if (!_isOnline) {
      // Offline — serve cached data; apply client-side filters if requested.
      if (_jobPosts.isEmpty) await _loadFromCache();
      notifyListeners();
      return;
    }

    try {
      final raw = await _jobRepo.getOpenPosts(
        search: search,
        category: category,
        minBudget: minBudget,
        maxBudget: maxBudget,
      );
      final fresh = _healJobPostNames(raw); // fix any stale client names
      _jobPosts          = fresh;
      _jobPostsFromCache = false;
      // Only persist the cache on unfiltered loads.
      final isUnfiltered =
          search == null && category == null &&
          minBudget == null && maxBudget == null;
      if (isUnfiltered && fresh.isNotEmpty) {
        await _jobRepo.cache(fresh);
        _jobCacheLastSyncedAt = DateTime.now();
      }
    } catch (_) {
      _isOnline = false;
      if (_jobPosts.isEmpty) await _loadFromCache();
    }
    notifyListeners();
  }

  /// Client: create a new job post.
  Future<String?> createJobPost(JobPost post) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _jobService.createPost(_currentUser!, post);
    if (error == null) {
      _myJobPosts.insert(0, post);
      // If it's an open post, add to feed too.
      if (post.status == JobStatus.open) _jobPosts.insert(0, post);
      notifyListeners();
    }
    return error;
  }

  /// Client: edit an existing job post.
  Future<String?> editJobPost(JobPost post) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _jobService.updatePost(_currentUser!, post);
    if (error == null) {
      _replaceInList(_myJobPosts, post);
      _replaceInList(_jobPosts, post);
      notifyListeners();
    }
    return error;
  }

  /// Client: close a job post (no longer accepting applications).
  Future<String?> closeJobPost(String postId, String ownerId) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _jobService.closePost(_currentUser!, postId, ownerId);
    if (error == null) {
      _updateJobPostStatus(postId, JobStatus.closed);
      // Reject lingering pending applications, notify each freelancer,
      // and clear the badge locally.
      _rejectPendingAndNotify(postId);
      notifyListeners();
    }
    return error;
  }

  /// Client: cancel a job post entirely.
  Future<String?> cancelJobPost(String postId, String ownerId) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _jobService.cancelPost(_currentUser!, postId, ownerId);
    if (error == null) {
      _updateJobPostStatus(postId, JobStatus.cancelled);
      // Reject lingering pending applications, notify each freelancer,
      // and clear the badge locally.
      _rejectPendingAndNotify(postId);
      notifyListeners();
    }
    return error;
  }

  /// Bulk-rejects all pending applications for a job, sends a bell notification
  /// to every affected freelancer, and updates the in-memory list.
  Future<void> _rejectPendingAndNotify(String jobId) async {
    try {
      final rejected =
          await _db.rejectAllPendingApplicationsForJob(jobId);
      _rejectPendingApplicationsLocally(jobId);

      // Look up job title once from in-memory lists.
      final jobPost = [..._myJobPosts, ..._jobPosts]
          .where((p) => p.id == jobId)
          .firstOrNull;
      final jobTitle = jobPost?.title ?? 'the job';

      for (final app in rejected) {
        try {
          await _notifSvc.send(NotificationService.makeApplicationRejected(
            freelancerId: app.freelancerId,
            jobTitle: jobTitle,
          ));
        } catch (_) {}
      }
    } catch (_) {
      // Non-critical — badge will still clear from local update.
    }
  }

  /// Update in-memory applications to rejected when their job is closed/cancelled.
  void _rejectPendingApplicationsLocally(String jobId) {
    for (int i = 0; i < _applications.length; i++) {
      if (_applications[i].jobId == jobId &&
          _applications[i].status == ApplicationStatus.pending) {
        _applications[i] =
            _applications[i].copyWith(status: ApplicationStatus.rejected);
      }
    }
  }

  /// Client: reopen a previously closed post.
  Future<String?> reopenJobPost(String postId, String ownerId) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _jobService.reopenPost(_currentUser!, postId, ownerId);
    if (error == null) {
      _updateJobPostStatus(postId, JobStatus.open);
      notifyListeners();
    }
    return error;
  }

  /// Soft-delete a job post (sets status = deleted; row kept in DB for auditing).
  Future<String?> removeJobPost(String postId, String ownerId) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _jobService.deletePost(_currentUser!, postId, ownerId);
    if (error == null) {
      _myJobPosts.removeWhere((p) => p.id == postId);
      _jobPosts.removeWhere((p) => p.id == postId);
      notifyListeners();
    }
    return error;
  }

  /// Reload current client's own posts (e.g. after returning from detail).
  Future<void> reloadMyJobPosts() async {
    if (_currentUser == null) return;
    _myJobPosts = await _jobRepo.getPostsByClient(_currentUser!.uid);
    notifyListeners();
  }

  /// Fetches the latest version of a single job post from Supabase and updates
  /// both in-memory lists. Used to refresh counters (applicationCount, viewCount)
  /// that may have changed on other devices since the post was last loaded.
  Future<void> refreshJobPost(String postId) async {
    try {
      final fresh = await _jobRepo.getById(postId);
      if (fresh == null) return;

      // Always use the live count from the applications table — this is the
      // source of truth and counts only PENDING applications (matching
      // Fiverr-style: withdrawn/rejected proposals don't inflate the number).
      // We intentionally ignore the application_count column on the job_posts
      // row because it is a write-ahead counter that is never decremented on
      // withdraw/reject and will always be >= the real active count.
      final realCount = await _db.getJobApplicationCount(postId);
      var withCount = fresh.copyWith(applicationCount: realCount);

      // Heal stale clientName — the DB row may still carry the old name if
      // updateUserDisplayNameEverywhere hasn't propagated yet.  Cross-reference
      // against the live _users list (same logic as _healJobPostNames) so the
      // detail page never flips back to an old name after the refresh.
      final liveClient =
          _users.where((u) => u.uid == withCount.clientId).firstOrNull;
      if (liveClient != null && liveClient.displayName != withCount.clientName) {
        withCount = withCount.copyWith(clientName: liveClient.displayName);
      }

      for (final list in [_jobPosts, _myJobPosts]) {
        final idx = list.indexWhere((p) => p.id == postId);
        if (idx >= 0) list[idx] = withCount;
      }
      notifyListeners();
    } catch (_) {
      // Non-critical — fail silently.
    }
  }

  /// Fire-and-forget view tracking — no UI feedback needed.
  void recordJobPostView(String postId) {
    _jobRepo.incrementViewCount(postId).catchError((_) {});
  }

  void _replaceInList(List<JobPost> list, JobPost updated) {
    final idx = list.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) list[idx] = updated;
  }

  void _updateJobPostStatus(String id, JobStatus status) {
    for (final list in [_myJobPosts, _jobPosts]) {
      final idx = list.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(status: status);
      }
    }
    // Remove from feed if no longer open.
    if (status != JobStatus.open) {
      _jobPosts.removeWhere((p) => p.id == id);
    }
  }

  // ── Freelancer Services ────────────────────────────────────────────────────

  /// Heals stale [FreelancerService.freelancerName] values in [services] by
  /// cross-referencing the live [_users] list — mirrors [_healJobPostNames].
  ///
  /// For every entry where the stored name differs from the live display name,
  /// the in-memory object is corrected and a background write updates both
  /// Supabase and the local SQLite cache so future loads are already correct.
  List<FreelancerService> _healServiceNames(List<FreelancerService> services) {
    if (_users.isEmpty) return services;

    final Map<String, String> fixes = {}; // freelancerId → correct name

    final healed = services.map((svc) {
      final knownUser =
          _users.where((u) => u.uid == svc.freelancerId).firstOrNull;
      if (knownUser != null && knownUser.displayName != svc.freelancerName) {
        fixes[svc.freelancerId] = knownUser.displayName;
        return svc.copyWith(freelancerName: knownUser.displayName);
      }
      return svc;
    }).toList();

    for (final entry in fixes.entries) {
      _db
          .updateUserDisplayNameEverywhere(entry.key, entry.value)
          .catchError(
              (e) => debugPrint('[healServiceNames] Supabase fix failed: $e'));
      _db
          .updateCachedFreelancerServiceName(entry.key, entry.value)
          .catchError(
              (e) => debugPrint('[healServiceNames] cache fix failed: $e'));
    }

    return healed;
  }

  /// Offline-first service feed loader.
  /// 1. Online  → fetch Supabase → heal names → cache top 20 → populate feed.
  /// 2. Offline → serve SQLite cache and show offline banner.
  Future<void> _loadServicesFeed() async {
    try {
      final raw = await _serviceRepo.getActiveServices();
      final fresh = _healServiceNames(raw); // fix any stale freelancer names
      _services = fresh;
      _servicesFromCache = false;
      if (fresh.isNotEmpty) await _serviceRepo.cache(fresh);
    } catch (_) {
      _services = _healServiceNames(await _serviceRepo.getCached());
      _servicesFromCache = _services.isNotEmpty;
    }
  }

  /// Public reload — called by pull-to-refresh or filter changes.
  Future<void> reloadServices({
    String? search,
    String? category,
    double? maxPrice,
  }) async {
    try {
      final raw = await _serviceRepo.getActiveServices(
        search: search,
        category: category,
        maxPrice: maxPrice,
      );
      final fresh = _healServiceNames(raw); // fix any stale freelancer names
      _services = fresh;
      _servicesFromCache = false;
      // Only update cache on unfiltered loads.
      if (search == null && category == null) {
        if (fresh.isNotEmpty) await _serviceRepo.cache(fresh);
      }
    } catch (_) {
      if (_services.isEmpty) {
        _services =
            _healServiceNames(await _serviceRepo.getCached());
        _servicesFromCache = _services.isNotEmpty;
      }
    }
    notifyListeners();
  }

  /// Freelancer: create a new service listing.
  Future<String?> createService(FreelancerService service) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _serviceLogic.createService(_currentUser!, service);
    if (error == null) {
      _myServices.insert(0, service);
      if (service.status == ServiceStatus.active) {
        _services.insert(0, service);
      }
      notifyListeners();
    }
    return error;
  }

  /// Freelancer: edit an existing service listing.
  Future<String?> editService(FreelancerService service) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _serviceLogic.updateService(_currentUser!, service);
    if (error == null) {
      _replaceServiceInList(_myServices, service);
      _replaceServiceInList(_services, service);
      // Ensure the feed only ever contains active services.
      if (service.status != ServiceStatus.active) {
        _services.removeWhere((s) => s.id == service.id);
      }
      notifyListeners();
    }
    return error;
  }

  /// Freelancer: deactivate a service (hides from public feed).
  Future<String?> deactivateService(
      String serviceId, String ownerId) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _serviceLogic.deactivateService(
        _currentUser!, serviceId, ownerId);
    if (error == null) {
      _updateServiceStatus(serviceId, ServiceStatus.inactive);
      notifyListeners();
    }
    return error;
  }

  /// Freelancer: re-activate an inactive service.
  Future<String?> activateService(
      String serviceId, String ownerId) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _serviceLogic.activateService(_currentUser!, serviceId, ownerId);
    if (error == null) {
      _updateServiceStatus(serviceId, ServiceStatus.active);
      notifyListeners();
    }
    return error;
  }

  /// Freelancer: soft-delete a service (sets status = deleted).
  Future<String?> removeService(String serviceId, String ownerId) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _serviceLogic.deleteService(_currentUser!, serviceId, ownerId);
    if (error == null) {
      _myServices.removeWhere((s) => s.id == serviceId);
      _services.removeWhere((s) => s.id == serviceId);
      notifyListeners();
    }
    return error;
  }

  /// Reload current freelancer's own services.
  Future<void> reloadMyServices() async {
    if (_currentUser == null) return;
    _myServices =
        await _serviceRepo.getServicesByFreelancer(_currentUser!.uid);
    notifyListeners();
  }

  /// Fire-and-forget view tracking.
  void recordServiceView(String serviceId) {
    _serviceLogic.recordView(serviceId);
  }

  void _replaceServiceInList(
      List<FreelancerService> list, FreelancerService updated) {
    final idx = list.indexWhere((s) => s.id == updated.id);
    if (idx >= 0) list[idx] = updated;
  }

  void _updateServiceStatus(String id, ServiceStatus status) {
    // Always update _myServices
    final myIdx = _myServices.indexWhere((s) => s.id == id);
    if (myIdx >= 0) {
      _myServices[myIdx] = _myServices[myIdx].copyWith(status: status);
    }

    if (status == ServiceStatus.active) {
      // Re-add to public feed if not already present
      final feedIdx = _services.indexWhere((s) => s.id == id);
      if (feedIdx >= 0) {
        _services[feedIdx] = _services[feedIdx].copyWith(status: status);
      } else if (myIdx >= 0) {
        _services.insert(0, _myServices[myIdx]);
      }
    } else {
      // Remove from public feed when no longer active
      _services.removeWhere((s) => s.id == id);
    }
  }

  // ── Service Orders ─────────────────────────────────────────────────────────

  Future<void> _loadServiceOrders() async {
    if (_currentUser == null) return;
    try {
      if (_currentUser!.role == UserRole.freelancer) {
        _serviceOrders =
            await _orderRepo.getByFreelancer(_currentUser!.uid);
      } else {
        _serviceOrders =
            await _orderRepo.getByClient(_currentUser!.uid);
      }
    } catch (_) {
      _serviceOrders = [];
    }
  }

  Future<void> reloadServiceOrders() async {
    await _loadServiceOrders();
    notifyListeners();
  }

  /// Called by ServiceOrdersPage's StreamBuilder on each Realtime emission
  /// to keep the in-memory list (used by badge counts) in sync.
  void syncServiceOrders(List<ServiceOrder> fresh) {
    if (fresh == _serviceOrders) return;
    _serviceOrders = fresh;
    notifyListeners();
  }

  /// Client: submit a new service order.
  Future<String?> submitServiceOrder(ServiceOrder order) async {
    if (_currentUser == null) return 'Not logged in.';

    // Guard: prevent duplicate active orders for the same service
    final hasActiveOrder = _serviceOrders.any((o) =>
        o.clientId == order.clientId &&
        o.serviceId == order.serviceId &&
        !o.status.isTerminal);
    if (hasActiveOrder) {
      return 'You already have an active order for this service. '
          'Wait for it to be resolved before placing a new one.';
    }

    final error = await _orderService.submitOrder(_currentUser!, order);
    if (error == null) {
      _serviceOrders.insert(0, order);
      // Notify the freelancer they have a new order to accept or reject.
      try {
        await _notifSvc.send(NotificationService.makeNewServiceOrder(
          freelancerId: order.freelancerId,
          serviceTitle: order.serviceTitle,
          clientName: _currentUser!.displayName ?? 'A client',
          orderId: order.id,
        ));
      } catch (_) {}
      notifyListeners();
    }
    return error;
  }

  /// Client: edit a pending service order.
  Future<String?> updateServiceOrder(ServiceOrder updated) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _orderService.editOrder(_currentUser!, updated);
    if (error == null) {
      _replaceOrderInList(updated);
      notifyListeners();
    }
    return error;
  }

  /// Client: cancel a pending service order.
  Future<String?> cancelServiceOrder(ServiceOrder order) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _orderService.cancelOrder(_currentUser!, order);
    if (error == null) {
      _replaceOrderInList(order.copyWith(status: ServiceOrderStatus.cancelled));
      notifyListeners();
    }
    return error;
  }

  /// Freelancer: accept a pending service order and auto-create a project.
  Future<String?> acceptServiceOrder(
      ServiceOrder order, String note) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _orderService.acceptOrder(_currentUser!, order, note);
    if (error != null) return error;

    // Create a project from the accepted order.
    final projectId = _uuid.v4();
    final client = await _db.getUserById(order.clientId);

    // ── Resolve total budget ─────────────────────────────────────────────
    // Priority: client's proposed budget → service listed price → null.
    double? resolvedBudget = order.proposedBudget;
    if (resolvedBudget == null) {
      final svc = await _serviceRepo.getById(order.serviceId);
      resolvedBudget = svc?.priceMax ?? svc?.priceMin;
    }

    // ── Resolve end date ─────────────────────────────────────────────────
    // Use timelineDays from the order as a tentative project deadline.
    // This ensures milestone date pickers are correctly constrained.
    final DateTime? resolvedEndDate = order.timelineDays != null
        ? DateTime.now().add(Duration(days: order.timelineDays!))
        : null;

    final project = ProjectItem(
      id: projectId,
      jobId: '',
      applicationId: '',
      clientId: order.clientId,
      freelancerId: order.freelancerId,
      status: ProjectStatus.pendingStart,
      jobTitle: order.serviceTitle,
      clientName: client?.displayName ?? order.clientName,
      freelancerName: _currentUser!.displayName,
      sourceType: 'service',
      serviceOrderId: order.id,
      totalBudget: resolvedBudget,
      endDate: resolvedEndDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.insertProject(project);

    // Mark order as converted.
    await _orderService.markConverted(order.id);

    _replaceOrderInList(
        order.copyWith(status: ServiceOrderStatus.convertedToProject));
    _projects.insert(0, project);

    // Notify the client their order was accepted and a project has been created.
    try {
      await _notifSvc.send(NotificationService.makeOrderAccepted(
        clientId: order.clientId,
        serviceTitle: order.serviceTitle,
        freelancerName: _currentUser!.displayName ?? 'The freelancer',
        projectId: projectId,
      ));
    } catch (_) {}

    notifyListeners();
    return null;
  }

  /// Freelancer: reject a pending service order.
  Future<String?> rejectServiceOrder(
      ServiceOrder order, String reason) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _orderService.rejectOrder(_currentUser!, order, reason);
    if (error == null) {
      _replaceOrderInList(
          order.copyWith(status: ServiceOrderStatus.rejected));
      // Notify the client their order was rejected.
      try {
        await _notifSvc.send(NotificationService.makeOrderRejected(
          clientId: order.clientId,
          serviceTitle: order.serviceTitle,
          freelancerName: _currentUser!.displayName ?? 'The freelancer',
          reason: reason,
          orderId: order.id,
        ));
      } catch (_) {}
      notifyListeners();
    }
    return error;
  }

  void _replaceOrderInList(ServiceOrder updated) {
    final idx = _serviceOrders.indexWhere((o) => o.id == updated.id);
    if (idx >= 0) _serviceOrders[idx] = updated;
  }

  // ── Marketplace ────────────────────────────────────────────────────────────

  Future<void> addPost(MarketplacePost post) async {
    await _db.insertPost(post);
    _posts.insert(0, post);
    notifyListeners();
  }

  Future<void> updatePost(MarketplacePost post) async {
    await _db.updatePost(post);
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx >= 0) _posts[idx] = post;
    notifyListeners();
  }

  Future<void> deletePost(String postId) async {
    await _db.deletePost(postId);
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  /// Reload posts from DB (e.g. after coming back online).
  Future<void> reloadPosts({bool useCache = false}) async {
    if (useCache) {
      _posts = await _db.getCachedJobs();
    } else {
      _posts = await _db.getActivePosts();
    }
    notifyListeners();
  }

  // ── Applications ───────────────────────────────────────────────────────────

  /// Returns null on success, error message on failure.
  Future<String?> addApplication(ApplicationItem app) async {
    final duplicate = await _db.hasApplied(app.jobId, app.freelancerId);
    if (duplicate) return 'You already applied to this job.';

    // Try the new JobPost system first, then fall back to legacy MarketplacePost.
    JobPost? jobPost = await _db.getJobPostById(app.jobId);
    if (jobPost != null) {
      if (!jobPost.isLive) {
        return 'This job is no longer accepting applications.';
      }
    } else {
      final legacyPost = await _db.getPostById(app.jobId);
      if (legacyPost == null) return 'Job not found.';
      if (legacyPost.isExpired) {
        return 'This job has expired and is no longer accepting applications.';
      }
      if (legacyPost.isAccepted) return 'This job has already been filled.';
    }

    await _db.insertApplication(app);
    _applications.insert(0, app);

    // Increment applicationCount on the cached JobPost in both lists.
    for (final list in [_jobPosts, _myJobPosts]) {
      final idx = list.indexWhere((p) => p.id == app.jobId);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(
          applicationCount: list[idx].applicationCount + 1,
        );
      }
    }

    // Persist the incremented count to Supabase (fire-and-forget).
    _jobRepo.incrementApplicationCount(app.jobId).catchError((_) {});

    // Notify the client that a new freelancer has applied to their job.
    try {
      final clientId = app.clientId.isNotEmpty ? app.clientId : jobPost?.clientId ?? '';
      if (clientId.isNotEmpty) {
        await _notifSvc.send(NotificationService.makeNewApplicant(
          clientId: clientId,
          jobTitle: jobPost?.title ?? 'your job',
          freelancerName: _currentUser?.displayName ?? 'A freelancer',
          jobId: app.jobId,
        ));
      }
    } catch (_) {}

    notifyListeners();
    return null;
  }

  Future<void> updateApplication(ApplicationItem app) async {
    await _db.updateApplication(app);
    final idx = _applications.indexWhere((a) => a.id == app.id);
    if (idx >= 0) _applications[idx] = app;
    notifyListeners();
  }

  Future<void> updateApplicationStatus(
      String appId, ApplicationStatus status) async {
    // Deactivated clients should not be able to change application statuses.
    if (_currentUser != null && !_currentUser!.isActive) return;
    await _db.updateApplicationStatus(appId, status);

    // Capture app reference before mutating the list (used for notification below).
    final appBefore = _applications.where((a) => a.id == appId).firstOrNull;

    final idx = _applications.indexWhere((a) => a.id == appId);
    if (idx >= 0) {
      _applications[idx] = _applications[idx].copyWith(status: status);
    }
    notifyListeners();

    // Send bell notification when a client manually rejects an application.
    if (status == ApplicationStatus.rejected && appBefore != null) {
      // Look up the job title from the client's in-memory job posts.
      final jobPost = [
        ..._myJobPosts,
        ..._jobPosts,
      ].where((p) => p.id == appBefore.jobId).firstOrNull;
      final jobTitle = jobPost?.title ?? 'your application';
      try {
        await _notifSvc.send(NotificationService.makeApplicationRejected(
          freelancerId: appBefore.freelancerId,
          jobTitle: jobTitle,
        ));
      } catch (_) {}
    }
  }

  /// Accept an application: locks winner, rejects others, marks post accepted,
  /// auto-creates a project.
  ///
  /// Returns `null` on success or an error message string on failure.
  /// All DB operations are wrapped in a single try/catch so a partial failure
  /// (e.g. network drop after status update) surfaces as an error rather than
  /// leaving the UI silently in a broken state.
  Future<String?> acceptApplication(ApplicationItem app) async {
    // Prevent duplicate calls from rapid tapping.
    if (_acceptingIds.contains(app.id)) return null;
    _acceptingIds.add(app.id);
    try {
      // Guard: deactivated clients cannot accept new applications.
      if (_currentUser != null && !_currentUser!.isActive) {
        return 'Your account is not active.';
      }
      // DB-level dedup: skip project creation if one already exists.
      final existing = await _db.getProjectByApplicationId(app.id);
      if (existing != null) {
        await _reloadUserData();
        notifyListeners();
        return null;
      }

      await _db.updateApplicationStatus(app.id, ApplicationStatus.accepted);
      // Fetch the pending losers before bulk-rejecting so we can notify them.
      final rejectedApps =
          await _db.rejectAllOtherApplications(app.jobId, app.id);

      // Close the job so no further applications are accepted.
      // Try new JobPost system first; fall back to legacy MarketplacePost.
      final acceptedJobPost = await _db.getJobPostById(app.jobId);
      if (acceptedJobPost != null) {
        await _db.updateJobPostStatus(app.jobId, JobStatus.closed);
      } else {
        await _db.markPostAccepted(app.jobId);
      }

      final projectId = _uuid.v4();
      // Resolve job title from whichever system owns this job.
      final legacyPost = acceptedJobPost == null
          ? await _db.getPostById(app.jobId)
          : null;
      final jobTitle = acceptedJobPost?.title ?? legacyPost?.title;
      final freelancer = await _db.getUserById(app.freelancerId);
      final client = await _db.getUserById(app.clientId);
      final project = ProjectItem(
        id: projectId,
        jobId: app.jobId,
        applicationId: app.id,
        clientId: app.clientId,
        freelancerId: app.freelancerId,
        status: ProjectStatus.pendingStart,
        jobTitle: jobTitle,
        clientName: client?.displayName,
        freelancerName: freelancer?.displayName,
        // Use the freelancer's proposed budget if they set one; otherwise
        // fall back to the job post's budget (budgetMax, then budgetMin).
        totalBudget: app.expectedBudget > 0
            ? app.expectedBudget
            : (acceptedJobPost?.budgetMax ?? acceptedJobPost?.budgetMin),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _db.insertProject(project);

      // Notify the winner their application was accepted.
      try {
        await _notifSvc.send(NotificationService.makeApplicationAccepted(
          freelancerId: app.freelancerId,
          jobTitle: jobTitle ?? 'the job',
          projectId: projectId,
        ));
      } catch (_) {}

      // Notify every other freelancer that their application was not selected.
      for (final rejected in rejectedApps) {
        try {
          await _notifSvc.send(NotificationService.makeApplicationRejected(
            freelancerId: rejected.freelancerId,
            jobTitle: jobTitle ?? 'the job',
          ));
        } catch (_) {}
      }

      await _reloadUserData();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to accept application: $e';
    } finally {
      _acceptingIds.remove(app.id);
    }
  }

  // ── Projects ───────────────────────────────────────────────────────────────

  Future<void> reloadProjects() async {
    if (_currentUser == null) return;
    _projects = await _db.getProjectsForUser(_currentUser!.uid);
    notifyListeners();
  }

  /// Fetch a single project directly from the DB (bypasses in-memory cache).
  Future<ProjectItem?> getProjectById(String id) => _db.getProjectById(id);

  /// Update a project's status using the typed [ProjectStatus] enum.
  Future<void> updateProjectStatus(
      String projectId, ProjectStatus status) async {
    await _db.updateProjectStatusEnum(projectId, status);
    _updateProjectInList(projectId,
        (p) => p.copyWith(status: status));
    notifyListeners();
  }

  /// Freelancer proposes the milestone plan. Project stays pendingStart until
  /// the client approves the plan and pays.
  Future<String?> proposeMilestonePlan(
    ProjectItem project,
    List<MilestoneItem> milestones,
  ) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _milestoneSvc.proposePlan(_currentUser!, project, milestones);
    if (error == null) {
      // Notify the client that the plan is ready for review and payment
      try {
        await _notifSvc.send(NotificationService.makePlanProposed(
          clientId: project.clientId,
          projectTitle: project.jobTitle ?? 'a project',
          milestoneCount: milestones.length,
          projectId: project.id,
        ));
      } catch (_) {}
      notifyListeners();
    }
    return error;
  }

  /// Client approves the milestone plan → project transitions to inProgress.
  Future<String?> approveMilestonePlan(
    ProjectItem project,
    List<MilestoneItem> milestones,
  ) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _milestoneSvc.approvePlan(_currentUser!, project, milestones);
    if (error == null) {
      _updateProjectInList(project.id,
          (p) => p.copyWith(status: ProjectStatus.inProgress));
      // Notify freelancer: payment secured, start working
      try {
        await _notifSvc.send(NotificationService.makePlanApproved(
          freelancerId: project.freelancerId,
          projectTitle: project.jobTitle ?? 'your project',
          heldAmount: project.totalBudget ?? 0,
          projectId: project.id,
        ));
      } catch (_) {}
      notifyListeners();
    }
    return error;
  }

  /// Client rejects the milestone plan — milestones are deleted so the
  /// freelancer can re-propose.
  Future<String?> rejectMilestonePlan(
    ProjectItem project,
    List<MilestoneItem> milestones,
  ) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _milestoneSvc.rejectPlan(_currentUser!, project, milestones);
    if (error == null) {
      // Notify the freelancer that their plan was rejected and they need to re-propose.
      try {
        await _notifSvc.send(InAppNotification(
          id: _uuid.v4(),
          userId: project.freelancerId,
          title: '❌ Milestone plan rejected',
          body: 'The client has rejected your milestone plan for '
              '"${project.jobTitle ?? 'your project'}". '
              'Please revise and propose a new plan.',
          type: NotificationType.milestoneRejected,
          linkedProjectId: project.id,
          createdAt: DateTime.now(),
        ));
      } catch (_) {}
    }
    notifyListeners();
    return error;
  }

  /// Client completes the project after all milestones are done.
  /// Requires a final digital signature.
  Future<String?> completeProject(
    ProjectItem project,
    List<MilestoneItem> milestones,
    String signatureUrl,
  ) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _projectSvc.completeProject(
        _currentUser!, project, milestones, signatureUrl);
    if (error == null) {
      _updateProjectInList(project.id,
          (p) => p.copyWith(status: ProjectStatus.completed,
              clientSignatureUrl: signatureUrl));
      _incrementServiceOrderCount(project);
      notifyListeners();
    }
    return error;
  }

  /// Either party cancels the project.
  /// On success, any held escrow balance is automatically refunded to the client.
  Future<String?> cancelProject(ProjectItem project, {String? reason}) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _projectSvc.cancelProject(_currentUser!, project, reason: reason);
    if (error == null) {
      _updateProjectInList(project.id,
          (p) => p.copyWith(
            status: ProjectStatus.cancelled,
            cancellationReason: reason,
          ));
      // Refund any remaining escrow balance
      await refundProjectPayment(project);
      notifyListeners();
    }
    return error;
  }

  // ── Payment Module ──────────────────────────────────────────────────────────

  /// Called after the client completes checkout.
  ///
  /// Creates a [PaymentRecord] in `pending` status, then immediately
  /// transitions it to `held` using the provided Stripe identifiers.
  /// The full contract amount is now held in escrow.
  Future<String?> processProjectPayment(
    ProjectItem project, {
    required String stripePaymentIntentId,
    required String stripePaymentMethodId,
  }) async {
    try {
      // Check if a record already exists (idempotent)
      PaymentRecord? existing =
          await _paymentRepo.getForProject(project.id);
      if (existing != null && existing.isHeld) {
        _currentPaymentRecord = existing;
        notifyListeners();
        return null; // already paid
      }

      // Derive total from milestones or project budget
      final milestones = await _db.getMilestonesForProject(project.id);
      final total = milestones.isNotEmpty
          ? milestones.fold<double>(0.0, (sum, m) => sum + m.paymentAmount)
          : (project.totalBudget ?? 0.0);

      // 1. Build and insert a pending record with the correct total
      final paymentId = _uuid.v4();
      final pending = PaymentRecord(
        id: paymentId,
        projectId: project.id,
        clientId: project.clientId,
        freelancerId: project.freelancerId,
        totalAmount: total,
        platformFeePercent: PaymentService.defaultPlatformFeePercent,
        heldAmount: 0,
        releasedAmount: 0,
        refundedAmount: 0,
        status: PaymentStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _paymentRepo.insert(pending);

      // 2. Transition to held (updates DB internally)
      final held = await _paymentSvc.holdPayment(
        pending,
        stripePaymentIntentId: stripePaymentIntentId,
        stripePaymentMethodId: stripePaymentMethodId,
      );

      _currentPaymentRecord = held;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Payment processing failed: $e';
    }
  }

  /// Loads (and caches) the [PaymentRecord] for a given project.
  Future<PaymentRecord?> loadPaymentForProject(String projectId) async {
    try {
      final record = await _paymentRepo.getForProject(projectId);
      if (record == null) {
        _currentPaymentRecord = null;
        notifyListeners();
        return null;
      }

      // Self-heal: cross-check releasedAmount against actual payout records.
      // If the payment record is stale (e.g. updated before payout tracking
      // was added), recalculate and persist the correct value.
      final payouts = await _paymentRepo.getPayoutsForProject(projectId);
      final actualReleased =
          payouts.fold(0.0, (sum, p) => sum + p.grossAmount);

      if (actualReleased > 0 &&
          (actualReleased - record.releasedAmount).abs() > 0.01) {
        final allReleased =
            (actualReleased - record.totalAmount).abs() < 0.01;
        final corrected = record.copyWith(
          releasedAmount: actualReleased,
          status: allReleased
              ? PaymentStatus.fullyReleased
              : PaymentStatus.partiallyReleased,
        );
        await _paymentRepo.update(corrected);
        _currentPaymentRecord = corrected;
      } else {
        _currentPaymentRecord = record;
      }

      notifyListeners();
      return _currentPaymentRecord;
    } catch (_) {
      return null;
    }
  }

  /// Loads all payout records for a given project.
  Future<List<PayoutRecord>> loadPayoutsForProject(
      String projectId) async {
    try {
      return await _paymentRepo.getPayoutsForProject(projectId);
    } catch (_) {
      return [];
    }
  }

  /// Refunds the remaining escrow balance back to the client.
  ///
  /// Called automatically on project cancellation and can also be
  /// triggered manually by an admin.
  Future<String?> refundProjectPayment(ProjectItem project) async {
    try {
      _currentPaymentRecord ??=
          await _paymentRepo.getForProject(project.id);
      if (_currentPaymentRecord == null) return null; // nothing to refund
      if (!_currentPaymentRecord!.isHeld) return null; // already settled

      // refundRemainingBalance is async and updates the DB internally
      final refunded =
          await _paymentSvc.refundRemainingBalance(_currentPaymentRecord!);
      _currentPaymentRecord = refunded;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Refund failed: $e';
    }
  }

  // ── Dispute Module ──────────────────────────────────────────────────────────

  /// Client or freelancer raises a formal dispute on a project.
  ///
  /// This:
  /// 1. Creates a [DisputeRecord] via [DisputeService].
  /// 2. Sets the project status to [ProjectStatus.disputed].
  /// 3. Sends an in-app notification to both parties.
  Future<String?> raiseDispute({
    required ProjectItem project,
    required DisputeReason reason,
    required String description,
    List<String> evidenceUrls = const [],
  }) async {
    if (_currentUser == null) return 'Not logged in.';
    try {
      final record = await _disputeSvc.raiseDispute(
        actor: _currentUser!,
        project: project,
        reason: reason,
        description: description,
        evidenceUrls: evidenceUrls,
      );

      _activeDispute = record;
      _updateProjectInList(
          project.id, (p) => p.copyWith(status: ProjectStatus.disputed));

      // Notify both parties
      final projectTitle = project.jobTitle ?? 'Project';
      await _notifSvc.send(NotificationService.makeDisputeRaised(
        userId: project.clientId,
        projectTitle: projectTitle,
        projectId: project.id,
        isRaiser: _currentUser!.uid == project.clientId,
      ));
      await _notifSvc.send(NotificationService.makeDisputeRaised(
        userId: project.freelancerId,
        projectTitle: projectTitle,
        projectId: project.id,
        isRaiser: _currentUser!.uid == project.freelancerId,
      ));

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Load (and cache locally) the active dispute for a given project.
  Future<DisputeRecord?> loadDisputeForProject(String projectId) async {
    try {
      final record = await _disputeRepo.getActiveForProject(projectId);
      _activeDispute = record;
      notifyListeners();
      return record;
    } catch (_) {
      return null;
    }
  }

  /// Admin: load all open/under-review disputes.
  Future<void> loadAllOpenDisputes() async {
    if (!isAdmin) return;
    try {
      _allOpenDisputes = await _disputeRepo.getAllOpen();
      notifyListeners();
    } catch (_) {}
  }

  /// Admin: load ALL disputes across all statuses (for the tabbed list view).
  Future<List<DisputeRecord>> loadAllDisputesForAdmin() async {
    if (!isAdmin) return [];
    try {
      final open = await _disputeRepo.getAllOpen();
      final resolved =
          await _disputeRepo.getAllByStatus(DisputeStatus.resolved);
      final closed = await _disputeRepo.getAllByStatus(DisputeStatus.closed);
      return [...open, ...resolved, ...closed];
    } catch (_) {
      return [];
    }
  }

  /// Admin: move a dispute to [DisputeStatus.underReview].
  Future<String?> startDisputeReview(DisputeRecord dispute) async {
    if (!isAdmin) return 'Access denied.';
    try {
      final updated = await _disputeSvc.startReview(dispute, _currentUser!.uid);
      _activeDispute = updated;
      _replaceDisputeInList(updated);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Admin: resolve a dispute and adjust escrow accordingly.
  Future<String?> resolveDispute({
    required DisputeRecord dispute,
    required DisputeResolution resolution,
    String adminNotes = '',
    double? clientRefundAmount,
  }) async {
    if (!isAdmin) return 'Access denied.';
    try {
      final result = await _disputeSvc.processResolution(
        dispute: dispute,
        resolution: resolution,
        adminId: _currentUser!.uid,
        adminNotes: adminNotes,
        clientRefundAmount: clientRefundAmount,
      );

      _activeDispute = result.dispute;
      _currentPaymentRecord = result.payment;
      _replaceDisputeInList(result.dispute);

      // Update project status in local list
      _updateProjectInList(
        dispute.projectId,
        (p) => p.copyWith(
          status: resolution == DisputeResolution.noAction
              ? ProjectStatus.inProgress   // dispute dismissed — resume project
              : ProjectStatus.cancelled,   // all other resolutions close the project
        ),
      );

      // Notify both parties
      final project = _projects
          .where((p) => p.id == dispute.projectId)
          .firstOrNull;
      final projectTitle = project?.jobTitle ?? 'Project';

      await _notifSvc.send(NotificationService.makeDisputeResolved(
        userId: dispute.clientId,
        projectTitle: projectTitle,
        resolutionLabel: resolution.displayName,
        projectId: dispute.projectId,
        isClient: true,
      ));
      await _notifSvc.send(NotificationService.makeDisputeResolved(
        userId: dispute.freelancerId,
        projectTitle: projectTitle,
        resolutionLabel: resolution.displayName,
        projectId: dispute.projectId,
        isClient: false,
      ));

      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Admin: close (archive) a resolved dispute.
  Future<String?> closeDispute(DisputeRecord dispute) async {
    if (!isAdmin) return 'Access denied.';
    try {
      final closed = await _disputeSvc.closeDispute(dispute);
      _activeDispute =
          _activeDispute?.id == closed.id ? closed : _activeDispute;
      _replaceDisputeInList(closed);
      _allOpenDisputes.removeWhere((d) => d.id == closed.id);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  void _replaceDisputeInList(DisputeRecord updated) {
    final idx = _allOpenDisputes.indexWhere((d) => d.id == updated.id);
    if (idx >= 0) {
      _allOpenDisputes[idx] = updated;
    }
  }

  void _updateProjectInList(
      String id, ProjectItem Function(ProjectItem) updater) {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx >= 0) _projects[idx] = updater(_projects[idx]);
  }

  /// Fire-and-forget: bumps `order_count` on the linked [FreelancerService]
  /// when a service-sourced project is completed.
  ///
  /// Does nothing for job-sourced projects or when the service order cannot
  /// be resolved.
  void _incrementServiceOrderCount(ProjectItem project) {
    if (project.sourceType != 'service' || project.serviceOrderId == null) {
      return;
    }
    _orderRepo.getById(project.serviceOrderId!).then((order) {
      if (order == null) return;
      // Persist to DB (fire-and-forget)
      _serviceRepo.incrementOrderCount(order.serviceId).catchError((_) {});
      // Update in-memory list so the UI refreshes immediately
      final idx = _myServices.indexWhere((s) => s.id == order.serviceId);
      if (idx >= 0) {
        _myServices[idx] =
            _myServices[idx].copyWith(orderCount: _myServices[idx].orderCount + 1);
        notifyListeners();
      }
    }).catchError((_) {});
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

  /// Freelancer submits a deliverable URL for the current milestone.
  Future<String?> submitMilestoneDeliverable(
    MilestoneItem milestone,
    String deliverableUrl,
  ) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _milestoneSvc.submitDeliverable(
        _currentUser!, milestone, deliverableUrl);
    if (error == null) {
      final idx = _milestones.indexWhere((m) => m.id == milestone.id);
      if (idx >= 0) {
        _milestones[idx] = _milestones[idx].copyWith(
            status: MilestoneStatus.submitted,
            deliverableUrl: deliverableUrl);
      }
      // Notify the client that work was submitted (DB fallback if _projects empty)
      final project = _projects.where((p) => p.id == milestone.projectId).firstOrNull
          ?? await _db.getProjectById(milestone.projectId);
      if (project != null) {
        try {
          await _notifSvc.send(NotificationService.makeMilestoneSubmitted(
            clientId: project.clientId,
            milestoneTitle: milestone.title,
            projectId: project.id,
            milestoneId: milestone.id,
          ));
        } catch (_) {}
      }
      notifyListeners();
    }
    return error;
  }

  /// Client approves a submitted milestone: sign + pay → completed.
  ///
  /// The legacy [paymentToken] parameter is retained for API compatibility.
  /// Prefer [approveAndPayMilestone] which integrates with the Payment Module.
  Future<void> approveMilestone(
      String milestoneId, String signaturePath, String paymentToken) async {
    await _db.approveMilestone(milestoneId, signaturePath, paymentToken);

    // Locate the milestone in the local cache once; use that single result
    // for both the advance call and the in-memory update.
    // (Using indexWhere avoids the crash that occurs when _milestones is empty
    // and a fallback of _milestones.first is attempted.)
    final idx = _milestones.indexWhere((m) => m.id == milestoneId);
    if (idx >= 0) {
      await _db.advanceMilestoneToNext(
          _milestones[idx].projectId, _milestones[idx].orderIndex);
      _milestones[idx] = _milestones[idx].copyWith(
        status: MilestoneStatus.completed,
        clientSignatureUrl: signaturePath,
        paymentToken: paymentToken,
      );

      // Notify the freelancer (fall back to DB lookup if _projects is empty)
      final milestone = _milestones[idx];
      final project = _projects.where((p) => p.id == milestone.projectId).firstOrNull
          ?? await _db.getProjectById(milestone.projectId);
      if (project != null) {
        try {
          await _notifSvc.send(NotificationService.makeMilestoneApproved(
            freelancerId: project.freelancerId,
            milestoneTitle: milestone.title,
            netAmount: milestone.paymentAmount * 0.9,
            projectId: project.id,
            milestoneId: milestone.id,
          ));
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  /// Payment-Module-aware milestone approval.
  ///
  /// 1. Loads the project's [PaymentRecord].
  /// 2. Creates a [PayoutRecord] (releases funds from escrow).
  /// 3. Marks the milestone as [MilestoneStatus.completed].
  /// 4. Auto-advances the next queued milestone to [MilestoneStatus.inProgress].
  ///
  /// Falls back to a simulated token when no payment record exists
  /// (e.g. the client skipped the checkout in sandbox mode).
  Future<String?> approveAndPayMilestone(
    MilestoneItem milestone,
    String signaturePath,
  ) async {
    try {
      // 1. Resolve payment record
      _currentPaymentRecord ??=
          await _paymentRepo.getForProject(milestone.projectId);

      String payoutToken;

      if (_currentPaymentRecord != null &&
          _currentPaymentRecord!.isHeld) {
        // 2. Release payout from escrow (DB record)
        try {
          final (updatedPayment, payout) =
              await _paymentSvc.releaseMilestonePayout(
            _currentPaymentRecord!,
            milestone,
            _uuid.v4(),
          );
          _currentPaymentRecord = updatedPayment;
          payoutToken = payout.payoutToken ??
              StripeService.generatePayoutReference();
        } catch (e) {
          payoutToken = StripeService.generatePayoutReference();
        }

        // 3. Real Stripe transfer to freelancer's connected account
        final project = _projects
            .where((p) => p.id == milestone.projectId)
            .firstOrNull;
        final intentId =
            _currentPaymentRecord?.stripePaymentIntentId ?? '';
        if (project != null && intentId.isNotEmpty) {
          try {
            final transferId = await StripeService.transferMilestonePayout(
              freelancerId: project.freelancerId,
              grossAmountMyr: milestone.paymentAmount,
              paymentIntentId: intentId,
              milestoneId: milestone.id,
            );
            payoutToken = transferId;
          } catch (e) {
            // Freelancer may not have set up Stripe Connect yet —
            // DB record is still updated, transfer logged as failed.
            print('[Payout] Transfer skipped: $e');
          }
        }
      } else {
        // No payment record — fallback reference.
        payoutToken = StripeService.generatePayoutReference();
      }

      // 3. Mark milestone complete in DB
      await _db.approveMilestone(
          milestone.id, signaturePath, payoutToken);

      // 4. Advance next approved milestone to inProgress
      await _db.advanceMilestoneToNext(
          milestone.projectId, milestone.orderIndex);

      // 5. Notify the freelancer (fall back to DB lookup if _projects is empty)
      final project = _projects.where((p) => p.id == milestone.projectId).firstOrNull
          ?? await _db.getProjectById(milestone.projectId);
      if (project != null) {
        try {
          await _notifSvc.send(NotificationService.makeMilestoneApproved(
            freelancerId: project.freelancerId,
            milestoneTitle: milestone.title,
            netAmount: milestone.paymentAmount * 0.9, // after 10% platform fee
            projectId: project.id,
            milestoneId: milestone.id,
          ));
        } catch (_) {}
      }

      // 6. Update local cache
      final idx = _milestones.indexWhere((m) => m.id == milestone.id);
      if (idx >= 0) {
        _milestones[idx] = _milestones[idx].copyWith(
          status: MilestoneStatus.completed,
          clientSignatureUrl: signaturePath,
          paymentToken: payoutToken,
        );
      }

      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to approve milestone: $e';
    }
  }

  /// Client rejects a submitted milestone with a reason.
  Future<String?> rejectMilestone(
      MilestoneItem milestone, String reason) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _milestoneSvc.rejectMilestone(
        _currentUser!, milestone, reason);
    if (error == null) {
      final idx = _milestones.indexWhere((m) => m.id == milestone.id);
      if (idx >= 0) {
        _milestones[idx] = _milestones[idx]
            .copyWith(status: MilestoneStatus.rejected, rejectionNote: reason);
      }
      // Notify the freelancer of the rejection (DB fallback if _projects empty)
      final project = _projects.where((p) => p.id == milestone.projectId).firstOrNull
          ?? await _db.getProjectById(milestone.projectId);
      if (project != null) {
        try {
        await _notifSvc.send(NotificationService.makeMilestoneRejected(
          freelancerId: project.freelancerId,
          milestoneTitle: milestone.title,
          reason: reason,
          projectId: project.id,
          milestoneId: milestone.id,
        ));
        } catch (_) {}
      }
      notifyListeners();
    }
    return error;
  }

  /// Freelancer revises a rejected milestone.
  Future<String?> reviseMilestone(MilestoneItem milestone) async {
    if (_currentUser == null) return 'Not logged in.';
    final error =
        await _milestoneSvc.reviseMilestone(_currentUser!, milestone);
    if (error == null) {
      final idx = _milestones.indexWhere((m) => m.id == milestone.id);
      if (idx >= 0) {
        _milestones[idx] = _milestones[idx].copyWith(
          status: MilestoneStatus.inProgress,
          revisionCount: milestone.revisionCount + 1,
        );
      }
      notifyListeners();
    }
    return error;
  }

  /// Freelancer requests a deadline extension.
  Future<String?> requestMilestoneExtension(
      MilestoneItem milestone, int days) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _milestoneSvc.requestExtension(
        _currentUser!, milestone, days);
    if (error == null) {
      final idx = _milestones.indexWhere((m) => m.id == milestone.id);
      if (idx >= 0) {
        _milestones[idx] = _milestones[idx].copyWith(
          extensionDays: days,
          extensionRequestedAt: DateTime.now(),
          extensionApproved: false,
        );
      }
      // Notify the client about the extension request
      final project = _projects
          .where((p) => p.id == milestone.projectId)
          .firstOrNull;
      if (project != null) {
        await _notifSvc.send(NotificationService.makeExtensionRequested(
          clientId: project.clientId,
          milestoneTitle: milestone.title,
          days: days,
          projectId: project.id,
          milestoneId: milestone.id,
        ));
      }
      notifyListeners();
    }
    return error;
  }

  /// Client approves a deadline extension.
  Future<String?> approveMilestoneExtension(MilestoneItem milestone) async {
    if (_currentUser == null) return 'Not logged in.';
    final error = await _milestoneSvc.approveExtension(
        _currentUser!, milestone);
    if (error == null) {
      final idx = _milestones.indexWhere((m) => m.id == milestone.id);
      if (idx >= 0) {
        _milestones[idx] =
            _milestones[idx].copyWith(extensionApproved: true);
      }
      // Notify the freelancer that their extension was approved
      if (milestone.extensionDays != null) {
        final project = _projects
            .where((p) => p.id == milestone.projectId)
            .firstOrNull;
        if (project != null) {
          await _notifSvc.send(NotificationService.makeExtensionApproved(
            freelancerId: project.freelancerId,
            milestoneTitle: milestone.title,
            days: milestone.extensionDays!,
            projectId: project.id,
            milestoneId: milestone.id,
          ));
        }
      }
      notifyListeners();
    }
    return error;
  }

  /// Client denies the freelancer's extension request.
  Future<String?> denyMilestoneExtension(MilestoneItem milestone) async {
    if (_currentUser == null) return 'Not logged in.';
    if (milestone.extensionRequestedAt == null) {
      return 'No extension request found.';
    }
    try {
      await _db.denyMilestoneExtension(milestone.id);
      final idx = _milestones.indexWhere((m) => m.id == milestone.id);
      if (idx >= 0) {
        _milestones[idx] = _milestones[idx].copyWith(
          extensionDays: null,
          extensionRequestedAt: null,
          extensionApproved: false,
        );
      }
      // Notify freelancer
      final project = _projects
          .where((p) => p.id == milestone.projectId)
          .firstOrNull;
      if (project != null) {
        await _notifSvc.send(NotificationService.makeExtensionDenied(
          freelancerId: project.freelancerId,
          milestoneTitle: milestone.title,
          projectId: project.id,
          milestoneId: milestone.id,
        ));
      }
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to deny extension: $e';
    }
  }

  Future<void> deleteMilestone(String milestoneId) async {
    await _db.deleteMilestone(milestoneId);
    _milestones.removeWhere((m) => m.id == milestoneId);
    notifyListeners();
  }

  // ── Single Delivery ────────────────────────────────────────────────────────

  /// Freelancer selects "Single Delivery" mode.
  /// Project stays [ProjectStatus.pendingStart] — it only moves to
  /// [ProjectStatus.inProgress] after the client pays (see [approveSingleDeliveryStart]).
  Future<String?> chooseSingleDelivery(ProjectItem project) async {
    if (_currentUser == null) return 'Not logged in.';
    if (_currentUser!.uid != project.freelancerId) return 'Access denied.';
    if (!project.isPendingStart) return 'Project is not in pending-start state.';

    try {
      await _db.markSingleDeliveryMode(project.id);
      _updateProjectInCache(project.copyWith(
        deliveryMode: ProjectDeliveryMode.single,
        // status stays pendingStart — client must pay first
      ));
      // Notify the client that the freelancer chose single delivery
      // and they need to pay to get work started.
      try {
        await _notifSvc.send(NotificationService.makePlanProposed(
          clientId: project.clientId,
          projectTitle: project.jobTitle ?? 'a project',
          milestoneCount: 1, // single delivery = 1 submission
          projectId: project.id,
        ));
      } catch (_) {}
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to choose single delivery: $e';
    }
  }

  /// Client pays for a Single Delivery project → project moves to inProgress.
  /// Freelancer is notified to start their work.
  Future<String?> approveSingleDeliveryStart(ProjectItem project) async {
    if (_currentUser == null) return 'Not logged in.';
    if (_currentUser!.uid != project.clientId) return 'Access denied.';
    if (!project.isPendingStart || !project.isSingleDelivery) {
      return 'Project is not awaiting single delivery payment.';
    }

    try {
      await _db.updateProjectStatusEnum(
        project.id,
        ProjectStatus.inProgress,
        startDate: DateTime.now(),
      );
      _updateProjectInCache(project.copyWith(
        status: ProjectStatus.inProgress,
        startDate: DateTime.now(),
      ));
      // Notify freelancer they can start working
      try {
        await _notifSvc.send(NotificationService.makePlanApproved(
          freelancerId: project.freelancerId,
          projectTitle: project.jobTitle ?? 'your project',
          heldAmount: project.totalBudget ?? 0,
          projectId: project.id,
        ));
      } catch (_) {}
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to start single delivery project: $e';
    }
  }

  /// Freelancer submits their single deliverable URL.
  Future<String?> submitSingleDelivery(
      ProjectItem project, String deliverableUrl) async {
    if (_currentUser == null) return 'Not logged in.';
    if (_currentUser!.uid != project.freelancerId) return 'Access denied.';
    if (!project.isSingleDelivery) return 'Project is not in single-delivery mode.';
    if (deliverableUrl.trim().isEmpty) {
      return 'Please provide a deliverable link or description.';
    }

    try {
      await _db.submitSingleDelivery(project.id, deliverableUrl.trim());
      _updateProjectInCache(project.copyWith(
        singleDeliverableUrl: deliverableUrl.trim(),
        singleRejectionNote: null,
      ));
      // Notify client
      try {
        await _notifSvc.send(
          NotificationService.makeMilestoneSubmitted(
            clientId: project.clientId,
            milestoneTitle: project.jobTitle ?? 'your project',
            projectId: project.id,
            milestoneId: project.id, // no milestone id in single mode
          ),
        );
      } catch (_) {}
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to submit deliverable: $e';
    }
  }

  /// Client approves the single-delivery submission: sign + pay → completed.
  Future<String?> approveSingleDelivery(
      ProjectItem project, String signaturePath) async {
    if (_currentUser == null) return 'Not logged in.';
    if (_currentUser!.uid != project.clientId) return 'Access denied.';
    if (!project.isSingleDeliverySubmitted) {
      return 'No deliverable has been submitted yet.';
    }

    try {
      // Resolve / simulate payment token
      _currentPaymentRecord ??=
          await _paymentRepo.getForProject(project.id);

      String payoutToken;
      if (_currentPaymentRecord != null && _currentPaymentRecord!.isHeld) {
        try {
          // Release full budget from escrow (single milestone = 100%)
          payoutToken = StripeService.generatePayoutReference();
        } catch (_) {
          payoutToken = StripeService.generatePayoutReference();
        }
      } else {
        payoutToken = StripeService.generatePayoutReference();
      }

      // Mark project completed
      await _db.updateProjectStatusEnum(
        project.id,
        ProjectStatus.completed,
        clientSignatureUrl: signaturePath,
      );

      _updateProjectInCache(project.copyWith(
        status: ProjectStatus.completed,
        clientSignatureUrl: signaturePath,
      ));

      _incrementServiceOrderCount(project);

      // Notify freelancer
      try {
        await _notifSvc.send(
          NotificationService.makeMilestoneApproved(
            freelancerId: project.freelancerId,
            milestoneTitle: project.jobTitle ?? 'the project',
            netAmount: (project.totalBudget ?? 0) * 0.9,
            projectId: project.id,
            milestoneId: project.id,
          ),
        );
      } catch (_) {}

      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to approve delivery: $e';
    }
  }

  /// Client rejects the single-delivery submission — freelancer must re-submit.
  Future<String?> rejectSingleDelivery(
      ProjectItem project, String reason) async {
    if (_currentUser == null) return 'Not logged in.';
    if (_currentUser!.uid != project.clientId) return 'Access denied.';
    if (!project.isSingleDeliverySubmitted) {
      return 'No deliverable has been submitted yet.';
    }
    if (reason.trim().isEmpty) return 'Please provide a rejection reason.';

    try {
      await _db.rejectSingleDelivery(project.id, reason.trim());
      _updateProjectInCache(project.copyWith(
        singleDeliverableUrl: null,
        singleRejectionNote: reason.trim(),
      ));
      // Notify freelancer
      try {
        await _notifSvc.send(
          NotificationService.makeMilestoneRejected(
            freelancerId: project.freelancerId,
            milestoneTitle: project.jobTitle ?? 'the project',
            reason: reason.trim(),
            projectId: project.id,
            milestoneId: project.id,
          ),
        );
      } catch (_) {}
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to reject delivery: $e';
    }
  }

  /// Updates or inserts [project] in the in-memory [_projects] cache.
  void _updateProjectInCache(ProjectItem project) {
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx >= 0) {
      _projects[idx] = project;
    } else {
      _projects.add(project);
    }
  }

  // ── Reviews ────────────────────────────────────────────────────────────────

  /// Submit a new review. Returns null on success, error message on failure.
  Future<String?> addReview(ReviewItem review) async {
    if (_currentUser == null) return 'Not logged in.';

    // Find the project to validate eligibility.
    final project = _projects.where((p) => p.id == review.projectId).firstOrNull
        ?? await _db.getProjectById(review.projectId);
    if (project == null) return 'Project not found.';

    final err = await _reviewSvc.submit(
      review: review,
      reviewer: _currentUser!,
      project: project,
    );
    if (err != null) return err;

    _reviews.insert(0, review);
    await _refreshRevieweeProfile(review.revieweeId);
    notifyListeners();
    return null;
  }

  /// Edit an existing review. Returns null on success, error message on failure.
  Future<String?> editReview(ReviewItem review, int stars, String comment) async {
    if (_currentUser == null) return 'Not logged in.';
    final err = await _reviewSvc.edit(
      review: review,
      editor: _currentUser!,
      newStars: stars,
      newComment: comment,
    );
    if (err != null) return err;

    final updated = review.copyWith(stars: stars, comment: comment);
    final idx = _reviews.indexWhere((r) => r.id == review.id);
    if (idx >= 0) _reviews[idx] = updated;
    await _refreshRevieweeProfile(review.revieweeId);
    notifyListeners();
    return null;
  }

  /// Legacy overload kept so existing callers still compile.
  Future<void> updateReview(ReviewItem review) async {
    await _db.updateReview(review);
    final idx = _reviews.indexWhere((r) => r.id == review.id);
    if (idx >= 0) _reviews[idx] = review;
    await _reviewRepo.updateStats(review.revieweeId);
    notifyListeners();
  }

  /// Delete a review. Returns null on success, error message on failure.
  Future<String?> removeReview(ReviewItem review) async {
    if (_currentUser == null) return 'Not logged in.';
    final err = await _reviewSvc.remove(
      review: review,
      actor: _currentUser!,
    );
    if (err != null) return err;

    _reviews.removeWhere((r) => r.id == review.id);
    _reportedReviews.removeWhere((r) => r.id == review.id);
    await _refreshRevieweeProfile(review.revieweeId);
    notifyListeners();
    return null;
  }

  /// Legacy overload — kept for any existing calls.
  Future<void> deleteReview(String reviewId, String revieweeId) async {
    await _db.deleteReview(reviewId);
    _reviews.removeWhere((r) => r.id == reviewId);
    _reportedReviews.removeWhere((r) => r.id == reviewId);
    await _reviewRepo.updateStats(revieweeId);
    notifyListeners();
  }

  /// Report a review as inappropriate.
  Future<String?> reportReview(ReviewItem review) async {
    if (_currentUser == null) return 'Not logged in.';
    final err = await _reviewSvc.report(
      review: review,
      reporter: _currentUser!,
    );
    if (err != null) return err;

    // Optimistically update local state.
    final updated = review.copyWith(
      status: ReviewStatus.reported,
      reportedBy: [...review.reportedBy, _currentUser!.uid],
    );
    _replaceReview(updated);
    notifyListeners();
    return null;
  }

  // ── Admin moderation ──────────────────────────────────────────────────────

  /// Admin: remove a reported/published review (soft remove).
  Future<void> adminRemoveReview(ReviewItem review) async {
    await _reviewSvc.adminRemove(review);
    _replaceReview(review.copyWith(status: ReviewStatus.removed));
    _reportedReviews.removeWhere((r) => r.id == review.id);
    await _refreshRevieweeProfile(review.revieweeId);
    notifyListeners();
  }

  /// Admin: restore a removed/reported review to published.
  Future<void> adminRestoreReview(ReviewItem review) async {
    await _reviewSvc.adminRestore(review);
    _replaceReview(review.copyWith(status: ReviewStatus.published));
    _reportedReviews.removeWhere((r) => r.id == review.id);
    await _refreshRevieweeProfile(review.revieweeId);
    notifyListeners();
  }

  /// Admin: reload the reported reviews list.
  Future<void> loadReportedReviews() async {
    if (!isAdmin) return;
    _reportedReviews = await _reviewSvc.getReported();
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _replaceReview(ReviewItem updated) {
    final idx = _reviews.indexWhere((r) => r.id == updated.id);
    if (idx >= 0) _reviews[idx] = updated;
  }

  Future<void> _refreshRevieweeProfile(String userId) async {
    final updated = await _db.getUserById(userId);
    if (updated != null) {
      final idx = _users.indexWhere((u) => u.uid == userId);
      if (idx >= 0) _users[idx] = updated;
      if (_currentUser?.uid == userId) _currentUser = updated;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<ProfileUser> get freelancers =>
      _users.where((u) => u.role == UserRole.freelancer).toList();

  Future<ProjectItem?> getCompletedProjectWith(String freelancerId) async {
    if (_currentUser == null) return null;
    return _db.getCompletedProjectBetween(_currentUser!.uid, freelancerId);
  }

  List<ProjectItem> get userProjects {
    if (_currentUser == null) return [];
    return _projects
        .where((p) =>
            p.clientId == _currentUser!.uid ||
            p.freelancerId == _currentUser!.uid)
        .toList();
  }

  List<ApplicationItem> get userApplications {
    if (_currentUser == null) return [];
    if (_currentUser!.role == UserRole.freelancer) {
      return _applications
          .where((a) => a.freelancerId == _currentUser!.uid)
          .toList();
    } else {
      return _applications
          .where((a) => a.clientId == _currentUser!.uid)
          .toList();
    }
  }

  Future<Map<String, double>> getMonthlyEarnings(String freelancerId) =>
      _reviewRepo.getMonthlyEarnings(freelancerId);

  Future<Map<int, int>> getRatingDistribution(String freelancerId) =>
      _reviewRepo.getRatingDistribution(freelancerId);

  Future<Map<String, double>> getMonthlyRatingTrend(String userId) =>
      _reviewRepo.getMonthlyRatingTrend(userId);

  Future<void> reloadApplications() async {
    if (_currentUser == null) return;
    _applications = _currentUser!.role == UserRole.freelancer
        ? await _appRepo.getByFreelancer(_currentUser!.uid)
        : await _appRepo.getByClient(_currentUser!.uid);
    notifyListeners();
  }

  // ── Portfolio ──────────────────────────────────────────────────────────────

  /// Loads portfolio items for [freelancerId] into [_portfolioItems].
  Future<void> loadPortfolioItems(String freelancerId) async {
    try {
      _portfolioItems = await _db.getPortfolioItems(freelancerId);
    } catch (_) {
      _portfolioItems = [];
    }
    notifyListeners();
  }

  Future<String?> addPortfolioItem(PortfolioItem item) async {
    try {
      await _db.insertPortfolioItem(item);
      _portfolioItems.insert(0, item);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to add portfolio item: $e';
    }
  }

  Future<String?> updatePortfolioItem(PortfolioItem item) async {
    try {
      await _db.updatePortfolioItem(item);
      final idx = _portfolioItems.indexWhere((p) => p.id == item.id);
      if (idx >= 0) _portfolioItems[idx] = item;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to update portfolio item: $e';
    }
  }

  Future<String?> deletePortfolioItem(String id) async {
    try {
      await _db.deletePortfolioItem(id);
      _portfolioItems.removeWhere((p) => p.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to delete portfolio item: $e';
    }
  }

  // ── Overdue Checker ─────────────────────────────────────────────────────────

  /// Start the 30-minute overdue polling timer.
  ///
  /// Call this after a successful login and on app resume.
  /// The timer is automatically cancelled on logout ([_stopOverdueChecker]).
  void startOverdueChecker() {
    _overdueTimer?.cancel();
    // Run immediately, then repeat every 30 minutes.
    _runOverdueCheck();
    _overdueTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _runOverdueCheck(),
    );
  }

  void _stopOverdueChecker() {
    _overdueTimer?.cancel();
    _overdueTimer = null;
  }

  /// Scan all in-progress projects belonging to the current user for overdue
  /// milestones and take the appropriate action (warn / enforce / resolve).
  Future<void> _runOverdueCheck() async {
    if (_currentUser == null) return;

    final uid = _currentUser!.uid;
    final activeProjects = _projects.where(
      (p) =>
          p.isInProgress &&
          (p.clientId == uid || p.freelancerId == uid),
    );

    for (final project in activeProjects) {
      try {
        final milestones = await _db.getMilestonesForProject(project.id);
        // Only the currently active (inProgress) milestone needs overdue checks.
        final active = milestones
            .where((m) => m.isInProgress)
            .firstOrNull;
        if (active == null) continue;

        final existingRecord =
            await _overdueRepo.getForMilestone(active.id);
        final action = await _overdueSvc.checkMilestone(
          milestone: active,
          project: project,
          existingRecord: existingRecord,
        );

        await _handleOverdueAction(action, project, active);
      } catch (_) {
        // Silently swallow per-project errors so one bad project
        // doesn't block the rest of the check.
      }
    }

    // Reload notifications after check so badge count updates.
    await loadNotifications();
  }

  Future<void> _handleOverdueAction(
    OverdueAction action,
    ProjectItem project,
    MilestoneItem milestone,
  ) async {
    if (action == OverdueAction.none || action == OverdueAction.resolved) {
      return;
    }

    final daysLeft = OverdueService.daysUntilDeadline(milestone);
    final projectTitle = project.jobTitle ?? 'Project';

    if (action == OverdueAction.enforce) {
      // ── Enforcement: cancel → restrict → refund ──────────────────────────
      // 1. Cancel project
      await _projectSvc.cancelProject(_currentUser!, project);
      _updateProjectInList(
          project.id, (p) => p.copyWith(status: ProjectStatus.cancelled));

      // 2. Restrict freelancer account
      await _db.updateAccountStatus(
          project.freelancerId, AccountStatus.restricted);

      // 3. Refund remaining escrow
      await refundProjectPayment(project);

      // 4. Notify both parties
      for (final targetIsFreelancer in [true, false]) {
        await _notifSvc.send(NotificationService.makeEnforcement(
          userId: targetIsFreelancer
              ? project.freelancerId
              : project.clientId,
          milestoneTitle: milestone.title,
          projectTitle: projectTitle,
          isFreelancer: targetIsFreelancer,
          projectId: project.id,
        ));
      }

      notifyListeners();
    } else if (action == OverdueAction.finalWarn) {
      // ── Final warning (24-h grace period started) ────────────────────────
      for (final targetIsFreelancer in [true, false]) {
        await _notifSvc.send(NotificationService.makeFinalWarning(
          userId: targetIsFreelancer
              ? project.freelancerId
              : project.clientId,
          milestoneTitle: milestone.title,
          projectTitle: projectTitle,
          isFreelancer: targetIsFreelancer,
          projectId: project.id,
          milestoneId: milestone.id,
        ));
      }
    } else {
      // ── 3-day / 1-day warning ───────────────────────────────────────────
      for (final targetIsFreelancer in [true, false]) {
        await _notifSvc.send(NotificationService.makeOverdueWarning(
          userId: targetIsFreelancer
              ? project.freelancerId
              : project.clientId,
          milestoneTitle: milestone.title,
          daysRemaining: daysLeft,
          projectId: project.id,
          milestoneId: milestone.id,
          isFreelancer: targetIsFreelancer,
        ));
      }
    }
  }

  // ── Notification helpers ───────────────────────────────────────────────────

  /// Subscribes to Supabase Realtime for the current user's notifications.
  /// Any INSERT or UPDATE on [in_app_notifications] for this user triggers an
  /// immediate UI refresh — no polling needed.
  void _startNotificationsStream() {
    _notifSub?.cancel();
    if (_currentUser == null) return;
    _notifSub = _db.notificationsStream(_currentUser!.uid).listen(
      (notifs) async {
        final prevCount = _notifications.length;
        _notifications = notifs;

        // If new project-status notifications arrived, reload the projects
        // list so ProjectDetailPage (and any other listener) sees the updated
        // status without requiring a manual pull-to-refresh.
        if (notifs.length > prevCount && _currentUser != null) {
          // All notification types that signal a project status change.
          const projectStatusTypes = {
            NotificationType.disputeResolved,
            NotificationType.disputeRaised,
            NotificationType.applicationAccepted,  // new project created
            NotificationType.orderAccepted,         // service order accepted → project created
            NotificationType.paymentHeld,           // escrow funded → project starts
            NotificationType.paymentReleased,       // milestone paid
            NotificationType.refundInitiated,       // cancellation / refund
            NotificationType.milestoneApproved,
            NotificationType.milestoneRejected,
            NotificationType.milestoneSubmitted,
            NotificationType.overdueEnforced,       // auto-cancel
          };
          final newNotifs =
              notifs.take(notifs.length - prevCount).toList();
          final hasProjectUpdate =
              newNotifs.any((n) => projectStatusTypes.contains(n.type));
          if (hasProjectUpdate) {
            _projects = await _db.getProjectsForUser(_currentUser!.uid);
          }
        }

        notifyListeners();
      },
      onError: (_) {
        // Stream errors are non-fatal; fall back to manual loads.
      },
    );
  }

  /// Loads the current user's notifications and updates the badge count.
  Future<void> loadNotifications() async {
    if (_currentUser == null) return;
    try {
      _notifications =
          await _notifSvc.loadForUser(_currentUser!.uid);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _notifSvc.markRead(notificationId);
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (_currentUser == null) return;
    await _notifSvc.markAllRead(_currentUser!.uid);
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  // ── Overdue record access ──────────────────────────────────────────────────

  /// Load all active (unresolved) overdue records for a specific project.
  Future<List<OverdueRecord>> loadOverdueRecordsForProject(
      String projectId) async {
    try {
      return await _overdueRepo.getActiveForProject(projectId);
    } catch (_) {
      return [];
    }
  }

  // ── Chat Module ─────────────────────────────────────────────────────────────

  /// Load (or refresh) the current user's chat room list + unread map.
  Future<void> loadChatRooms() async {
    if (_currentUser == null) return;
    try {
      _chatRooms = await _chatRepo.getRoomsForUser(_currentUser!.uid);
      _chatUnreadMap =
          await _chatSvc.unreadRooms(_currentUser!.uid, _chatRooms);

      // Collect all unique participant UIDs (excluding ourselves) so we can
      // resolve them to display names for room titles.
      final myId = _currentUser!.uid;
      final otherIds = _chatRooms
          .expand((r) => r.participantIds)
          .where((id) => id != myId)
          .toSet()
          .toList();
      if (otherIds.isNotEmpty) {
        final names = await _db.getDisplayNamesByIds(otherIds);
        _chatUserNames = {..._chatUserNames, ...names};
      }

      notifyListeners();
    } catch (_) {}
  }

  /// Open (or create) a direct chat room with another user.
  Future<ChatRoom?> openDirectChat(String otherUserId) async {
    if (_currentUser == null) return null;
    try {
      final room = await _chatSvc.getOrCreateDirectRoom(
          _currentUser!.uid, otherUserId);
      _upsertRoom(room);

      // Ensure the other user's name is in _chatUserNames so the AppBar
      // title shows their name instead of "Direct Message" immediately.
      if (!_chatUserNames.containsKey(otherUserId)) {
        // Try the already-loaded users list first (no extra DB call)
        final cached = _users.cast<ProfileUser?>()
            .firstWhere((u) => u?.uid == otherUserId, orElse: () => null);
        if (cached != null) {
          _chatUserNames = {..._chatUserNames, otherUserId: cached.displayName};
        } else {
          // Fall back to a DB lookup for users not yet loaded
          final names = await _db.getDisplayNamesByIds([otherUserId]);
          if (names.isNotEmpty) {
            _chatUserNames = {..._chatUserNames, ...names};
          }
        }
      }

      notifyListeners();
      return room;
    } catch (_) {
      return null;
    }
  }

  /// Open (or create) a project-scoped chat room.
  Future<ChatRoom?> openProjectChat(ProjectItem project) async {
    if (_currentUser == null) return null;
    try {
      final room = await _chatSvc.getOrCreateProjectRoom(project);
      _upsertRoom(room);
      notifyListeners();
      return room;
    } catch (_) {
      return null;
    }
  }

  /// Send a message and notify all other participants.
  ///
  /// Returns an error string on failure, null on success.
  Future<String?> sendChatMessage(ChatRoom room, String content) async {
    if (_currentUser == null) return 'Not logged in.';
    try {
      final msg = await _chatSvc.sendMessage(
        room: room,
        sender: _currentUser!,
        content: content,
      );

      // Notify all other participants (except sender) silently
      for (final uid in room.participantIds) {
        if (uid == _currentUser!.uid) continue;
        await _notifSvc.send(NotificationService.makeNewChatMessage(
          recipientId: uid,
          senderName: _currentUser!.displayName,
          messagePreview:
              msg.content.length > 60
                  ? '${msg.content.substring(0, 60)}…'
                  : msg.content,
          chatRoomId: room.id,
          linkedProjectId: room.projectId,
        ));
      }

      // Update local room list with new preview
      final updated = room.copyWith(
        lastMessage: msg.content,
        lastSenderId: _currentUser!.uid,
        lastSenderName: _currentUser!.displayName,
        lastMessageAt: msg.createdAt,
      );
      _upsertRoom(updated);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Load messages for a chat room (oldest-first for display).
  Future<List<ChatMessage>> loadChatMessages(
    String roomId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _chatSvc.loadMessages(roomId, limit: limit, offset: offset);
    } catch (_) {
      return [];
    }
  }

  /// Mark all messages in [roomId] as read for the current user.
  /// Also silently marks any newChatMessage notifications for this room as
  /// read so the bell badge clears together with the chat unread dot.
  Future<void> markChatRoomRead(String roomId) async {
    if (_currentUser == null) return;
    try {
      // Write the read timestamp using server NOW() (via RPC) so the
      // timestamp is always >= the message's server timestamp — eliminates
      // the clock-skew bug where device time < server time made the room
      // appear unread again after the Realtime stream refreshed.
      await _chatSvc.markRead(roomId, _currentUser!.uid);

      // Immediately clear in-memory so the dot vanishes without waiting for
      // the next stream emission.
      _chatUnreadMap[roomId] = false;

      // Clear matching newChatMessage notification records locally + in DB.
      final chatNotifIds = _notifications
          .where((n) =>
              !n.isRead &&
              n.type == NotificationType.newChatMessage &&
              n.linkedChatRoomId == roomId)
          .map((n) => n.id)
          .toList();
      for (final id in chatNotifIds) {
        _notifSvc.markRead(id).catchError((_) {});
      }
      if (chatNotifIds.isNotEmpty) {
        _notifications = _notifications
            .map((n) => chatNotifIds.contains(n.id) ? n.copyWith(isRead: true) : n)
            .toList();
      }

      notifyListeners();

      // Re-fetch the unread map from DB so the badge stays accurate after
      // the server write. Fire-and-forget: failures are non-critical.
      _chatSvc
          .unreadRooms(_currentUser!.uid, _chatRooms)
          .then((fresh) {
            _chatUnreadMap = fresh;
            notifyListeners();
          })
          .catchError((_) {});
    } catch (_) {}
  }

  void _upsertRoom(ChatRoom room) {
    final idx = _chatRooms.indexWhere((r) => r.id == room.id);
    if (idx >= 0) {
      _chatRooms[idx] = room;
    } else {
      _chatRooms.insert(0, room);
    }
    // Re-sort by last message timestamp
    _chatRooms.sort((a, b) {
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
  }
}
