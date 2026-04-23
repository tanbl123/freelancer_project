import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../shared/enums/appeal_status.dart';
import '../../../state/app_state.dart';
import '../../applications/screens/ra_dashboard_screen.dart';
import '../../disputes/screens/admin/admin_dispute_list_screen.dart';
import '../../jobs/screens/job_feed_screen.dart';
import '../../profile/models/profile_user.dart';
import '../../profile/screens/edit_profile_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../ratings/screens/admin/admin_review_list_screen.dart';
import '../../services/screens/service_feed_screen.dart';
import '../../transactions/screens/project_list_page.dart';
import '../../user/screens/admin/admin_freelancer_requests_screen.dart';
import '../../user/screens/admin/admin_user_list_screen.dart';

/// Bottom-navigation shell that replaces the old module-tile dashboard.
/// Each tab keeps its state via IndexedStack.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with WidgetsBindingObserver {
  late int _currentIndex;

  // Titles and pages for regular users (client / freelancer).
  static const _tabTitles = [
    'Jobs',
    'Services',
    'Applications',
    'My Projects',
    'My Profile',
  ];

  static const _pages = [
    JobFeedScreen(),
    ServiceFeedScreen(),
    RaDashboardScreen(),
    ProjectListPage(),
    ProfilePage(),
  ];

  // Admin-specific tabs.
  static const _adminTitles = [
    'Manage Users',
    'Requests',
    'Manage Reviews',
    'Manage Disputes',
    'My Profile',
  ];
  static const _adminPages = [
    AdminUserListScreen(),
    AdminFreelancerRequestsScreen(),
    AdminReviewListScreen(),
    AdminDisputeListScreen(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    // Start the 30-minute overdue polling and load initial notifications.
    AppState.instance.startOverdueChecker();
    AppState.instance.loadNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-run the overdue check immediately when the user returns to the app.
    if (state == AppLifecycleState.resumed) {
      AppState.instance.startOverdueChecker();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        // Badge count: pending applications relevant to the current user.
        final user = AppState.instance.currentUser;
        // Combined badge: pending job applications + pending service orders.
        final pendingApps = user == null
            ? 0
            : user.role == UserRole.client
                // Clients: pending apps on their own job posts.
                ? AppState.instance.applications
                    .where((a) =>
                        a.status == ApplicationStatus.pending &&
                        AppState.instance.posts
                            .any((p) => p.id == a.jobId && p.ownerId == user.uid))
                    .length
                // Freelancers: their own pending applications.
                : AppState.instance.applications
                    .where((a) =>
                        a.freelancerId == user.uid &&
                        a.status == ApplicationStatus.pending)
                    .length;

        final pendingOrders = user == null
            ? 0
            : AppState.instance.serviceOrders
                .where((o) => o.status == ServiceOrderStatus.pending)
                .length;

        final pendingCount = pendingApps + pendingOrders;

        final unreadCount =
            AppState.instance.unreadNotificationCount;

        final unreadChatCount = AppState.instance.unreadChatCount;

        // ── Per-tab page-specific actions ─────────────────────────────────
        final bool isAdmin      = user?.role == UserRole.admin;
        final bool isFreelancer = user?.role == UserRole.freelancer;
        final bool isClient     = user?.role == UserRole.client;

        // Clamp index to valid range for the current role's tab count.
        final int maxIndex =
            (isAdmin ? _adminPages.length : _pages.length) - 1;
        final int effectiveIndex = _currentIndex.clamp(0, maxIndex);
        if (effectiveIndex != _currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentIndex = effectiveIndex);
          });
        }

        final currentTitle = isAdmin
            ? _adminTitles[effectiveIndex]
            : _tabTitles[effectiveIndex];

        final List<Widget> tabActions = [
          // ── Tab 0: Jobs — clients get a "Post a Job" shortcut ────────────
          if (!isAdmin && effectiveIndex == 0 && isClient)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Post a Job',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.jobForm),
            ),

          // ── Profile tab — edit shortcut ───────────────────────────────────
          if (effectiveIndex == 4) ...[
            if (!isAdmin && isFreelancer && user != null)
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share Profile',
                onPressed: () => Share.share(
                  'Check out ${user.displayName} on FreelancerApp!\n'
                  'Rating: ${user.averageRating?.toStringAsFixed(1) ?? 'New'}/5'
                  ' (${user.totalReviews ?? 0} reviews)\n'
                  'Skills: ${user.skills.take(5).join(', ')}',
                ),
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EditProfilePage()),
              ),
            ),
          ],

          // ── Global actions (always visible) ──────────────────────────────
          IconButton(
            tooltip: 'Messages',
            icon: Badge(
              isLabelVisible: unreadChatCount > 0,
              label: Text(
                  unreadChatCount > 99 ? '99+' : '$unreadChatCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.chatList),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
          ),
          IconButton(
            tooltip: 'Overdue Overview',
            icon: const Icon(Icons.warning_amber_outlined),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.overdueDashboard),
          ),
        ];

        // ── Logout / session-expiry guard ──────────────────────────────────
        if (!AppState.instance.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.welcome, (_) => false);
            }
          });
        }

        // ── Admin shell ───────────────────────────────────────────────────
        if (isAdmin) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(currentTitle),
              centerTitle: false,
              actions: tabActions,
            ),
            body: IndexedStack(
              index: effectiveIndex,
              children: _adminPages,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: effectiveIndex,
              onDestinationSelected: (i) =>
                  setState(() => _currentIndex = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt),
                  label: 'Users',
                ),
                NavigationDestination(
                  // Badge shows combined count: pending requests + open appeals
                  icon: Badge(
                    isLabelVisible: () {
                      final pendingReqs = AppState.instance.allFreelancerRequests
                          .where((r) => r.status.name == 'pending')
                          .length;
                      final openAppeals = AppState.instance.allAppeals
                          .where((a) =>
                              a.status == AppealStatus.open ||
                              a.status == AppealStatus.underReview)
                          .length;
                      return pendingReqs + openAppeals > 0;
                    }(),
                    label: Text(() {
                      final pendingReqs = AppState.instance.allFreelancerRequests
                          .where((r) => r.status.name == 'pending')
                          .length;
                      final openAppeals = AppState.instance.allAppeals
                          .where((a) =>
                              a.status == AppealStatus.open ||
                              a.status == AppealStatus.underReview)
                          .length;
                      final total = pendingReqs + openAppeals;
                      return total > 99 ? '99+' : '$total';
                    }()),
                    child: const Icon(Icons.work_outline),
                  ),
                  selectedIcon: const Icon(Icons.work),
                  label: 'Requests',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.star_outline),
                  selectedIcon: Icon(Icons.star),
                  label: 'Reviews',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.gavel_outlined),
                  selectedIcon: Icon(Icons.gavel),
                  label: 'Disputes',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          );
        }

        // ── Regular user shell ─────────────────────────────────────────────
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(currentTitle),
            centerTitle: false,
            actions: tabActions,
          ),
          body: IndexedStack(index: effectiveIndex, children: _pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: effectiveIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.work_outline),
                selectedIcon: Icon(Icons.work),
                label: 'Jobs',
              ),
              const NavigationDestination(
                icon: Icon(Icons.design_services_outlined),
                selectedIcon: Icon(Icons.design_services),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.description_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.description),
                ),
                label: 'Applications',
              ),
              const NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: 'Projects',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
