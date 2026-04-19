import 'package:flutter/material.dart';

import '../features/applications/screens/apply_form_page.dart';
import '../features/applications/screens/incoming_applications_screen.dart';
import '../features/applications/screens/ra_dashboard_screen.dart';
import '../features/applications/screens/service_order_form_page.dart';
import '../features/applications/screens/service_orders_page.dart';
import '../features/welcome/screens/welcome_page.dart';
import '../features/applications/screens/job_applications_page.dart';
import '../features/authentication/screens/forgot_password_page.dart';
import '../features/authentication/screens/login_page.dart';
import '../features/authentication/screens/register_page.dart';
import '../features/home/screens/main_shell.dart';
import '../features/marketplace/screens/marketplace_feed_page.dart';
import '../features/marketplace/screens/post_form_page.dart';
import '../features/marketplace/models/marketplace_post.dart';
import '../features/profile/screens/change_password_page.dart';
import '../features/profile/screens/edit_profile_page.dart';
import '../features/profile/screens/freelancer_profile_page.dart';
import '../features/profile/screens/profile_page.dart';
import '../features/ratings/screens/freelancer_stats_page.dart';
import '../features/ratings/screens/review_form_page.dart';
import '../features/transactions/models/milestone_item.dart';
import '../features/transactions/models/project_item.dart';
import '../features/transactions/screens/milestone_form_page.dart';
import '../features/transactions/screens/milestone_plan_page.dart';
import '../features/transactions/screens/milestone_plan_review_page.dart';
import '../features/transactions/screens/project_completion_page.dart';
import '../features/transactions/screens/project_detail_page.dart';
import '../features/transactions/screens/project_list_page.dart';
import '../features/jobs/models/job_post.dart';
import '../features/jobs/screens/job_detail_screen.dart';
import '../features/jobs/screens/job_feed_screen.dart';
import '../features/jobs/screens/job_form_screen.dart';
import '../features/jobs/screens/my_job_posts_screen.dart';
import '../features/services/models/freelancer_service.dart';
import '../features/profile/models/portfolio_item.dart';
import '../features/profile/screens/portfolio_form_screen.dart';
import '../features/services/screens/my_services_screen.dart';
import '../features/services/screens/service_detail_screen.dart';
import '../features/services/screens/service_feed_screen.dart';
import '../features/services/screens/service_form_screen.dart';
import '../features/chat/models/chat_room.dart';
import '../features/chat/screens/chat_list_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/disputes/models/dispute_record.dart';
import '../features/disputes/screens/dispute_create_screen.dart';
import '../features/disputes/screens/admin/admin_dispute_list_screen.dart';
import '../features/disputes/screens/admin/admin_dispute_review_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/ratings/models/review_item.dart';
import '../features/ratings/screens/admin/admin_review_list_screen.dart';
import '../features/ratings/screens/review_create_edit_screen.dart';
import '../features/overdue/screens/overdue_dashboard_screen.dart';
import '../features/payment/screens/checkout_screen.dart';
import '../features/payment/screens/payment_status_screen.dart';
import '../features/user/screens/admin/admin_freelancer_requests_screen.dart';
import '../features/user/screens/admin/admin_user_detail_screen.dart';
import '../features/user/screens/admin/admin_user_list_screen.dart';
import '../features/user/screens/appeal_screen.dart';
import '../features/user/screens/email_verification_screen.dart';
import '../features/user/screens/freelancer_request_screen.dart';
import '../state/app_state.dart';

class AppRoutes {
  static const welcome = '/';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const marketplace = '/marketplace';
  static const marketplaceForm = '/marketplace/form';
  static const applications = '/applications';
  static const applicationApply = '/applications/apply';
  static const raDashboard = '/ra';
  static const serviceOrders = '/applications/service-orders';
  static const serviceOrderForm = '/applications/service-orders/form';
  static const projects = '/projects';
  static const transactions = '/transactions';
  static const transactionsMilestone = '/transactions/milestone';
  static const ratings = '/ratings';
  static const ratingsStats = '/ratings/stats';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const changePassword = '/profile/change-password';
  static const userProfile = '/profile/view'; // public profile viewer
  static const emailVerification = '/verify-email';
  static const freelancerRequest = '/freelancer-request';
  static const appeal = '/appeal';
  static const forgotPassword = '/forgot-password';
  static const adminUsers = '/admin/users';
  static const adminUserDetail = '/admin/users/detail';
  static const adminRequests = '/admin/freelancer-requests';

  // ── Project & Milestone Module ─────────────────────────────────────────────
  static const milestonePlan       = '/projects/milestone-plan';
  static const milestonePlanReview = '/projects/milestone-plan/review';
  static const projectCompletion   = '/projects/completion';

  // ── Payment Module ─────────────────────────────────────────────────────────
  static const paymentCheckout = '/payment/checkout';
  static const paymentStatus   = '/payment/status';

  // ── Overdue & Notification Module ──────────────────────────────────────────
  static const notifications    = '/notifications';
  static const overdueDashboard = '/overdue';

  // ── Review Module ──────────────────────────────────────────────────────────
  static const reviewCreate  = '/reviews/create';
  static const reviewEdit    = '/reviews/edit';
  static const adminReviews  = '/admin/reviews';

  // ── Chat Module ────────────────────────────────────────────────────────────
  static const chatList = '/chat';
  static const chatRoom = '/chat/room';

  // ── Dispute Module ─────────────────────────────────────────────────────────
  static const disputeCreate      = '/disputes/create';
  static const adminDisputeList   = '/admin/disputes';
  static const adminDisputeReview = '/admin/disputes/review';

  // ── Incoming Applications (client-facing realtime screen) ──────────────────
  static const incomingApplications = '/applications/incoming';

  // ── Job Posting Module ─────────────────────────────────────────────────────
  static const jobFeed = '/jobs';
  static const jobDetail = '/jobs/detail';
  static const jobForm = '/jobs/form';
  static const myJobPosts = '/jobs/my-posts';

  // ── Provide Service Module ─────────────────────────────────────────────────
  static const serviceFeed = '/services';
  static const serviceDetail = '/services/detail';
  static const serviceForm = '/services/form';
  static const myServices = '/services/my-services';

  // ── Portfolio Module ───────────────────────────────────────────────────────
  static const portfolioForm = '/profile/portfolio/form';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? '';

    // ── Deep-link / OAuth callback guard ──────────────────────────────────────
    // When Android resumes the app via the custom URI scheme Flutter strips the
    // scheme+host and passes only the path, so settings.name ends up as
    // something like "/login-callback?code=..." or "//login-callback?code=...".
    // None of those match our named routes, so we catch them here before the
    // switch.  app_links + Supabase already handle the actual auth exchange;
    // we just need to land somewhere safe.  WelcomePage listens to AppState
    // and will redirect to the dashboard the moment onAuthStateChange fires.
    if (routeName.contains('login-callback') ||
        routeName.startsWith('io.supabase.freelancerapp')) {
      return MaterialPageRoute(builder: (_) => const WelcomePage());
    }
    // ─────────────────────────────────────────────────────────────────────────

    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomePage());

      case AppRoutes.login:
        // If already logged in, skip the login page and go straight to the app
        if (AppState.instance.isLoggedIn) {
          return MaterialPageRoute(
              builder: (_) => const MainShell());
        }
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case AppRoutes.register:
        // If already logged in, skip the register page and go straight to the app
        if (AppState.instance.isLoggedIn) {
          return MaterialPageRoute(
              builder: (_) => const MainShell());
        }
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      case AppRoutes.dashboard:
        // If the user needs to verify their email, send them there first
        if (AppState.instance.needsEmailVerification) {
          return MaterialPageRoute(
              builder: (_) => const EmailVerificationScreen());
        }
        final idx = settings.arguments as int?;
        return MaterialPageRoute(
            builder: (_) => MainShell(initialIndex: idx ?? 0));

      case AppRoutes.marketplace:
        return MaterialPageRoute(
            builder: (_) => const MarketplaceFeedPage());

      case AppRoutes.marketplaceForm:
        final post = settings.arguments as MarketplacePost?;
        return MaterialPageRoute(
            builder: (_) => PostFormPage(existing: post));

      case AppRoutes.applications:
        return MaterialPageRoute(
            builder: (_) => const JobApplicationsPage());

      case AppRoutes.raDashboard:
        return MaterialPageRoute(
            builder: (_) => const RaDashboardScreen());

      // Optional argument: String jobId — narrows the list to one job.
      case AppRoutes.incomingApplications:
        final jobId = settings.arguments as String?;
        return MaterialPageRoute(
            builder: (_) => IncomingApplicationsScreen(jobId: jobId));

      case AppRoutes.serviceOrders:
        return MaterialPageRoute(
            builder: (_) => const ServiceOrdersPage());

      case AppRoutes.serviceOrderForm:
        final service = settings.arguments as FreelancerService;
        return MaterialPageRoute(
            builder: (_) => ServiceOrderFormPage(service: service));

      case AppRoutes.applicationApply:
        final arg = settings.arguments;
        if (arg is JobPost) {
          return MaterialPageRoute(
              builder: (_) => ApplyFormPage(preselectedJobPost: arg));
        }
        final post = arg as MarketplacePost?;
        return MaterialPageRoute(
            builder: (_) => ApplyFormPage(preselectedPost: post));

      case AppRoutes.projects:
        return MaterialPageRoute(
            builder: (_) => const ProjectListPage());

      case AppRoutes.transactions:
        final projectId = settings.arguments as String;
        return MaterialPageRoute(
            builder: (_) => ProjectDetailPage(projectId: projectId));

      case AppRoutes.transactionsMilestone:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => MilestoneFormPage(
            projectId: args['projectId'] as String,
            totalBudget: (args['totalBudget'] as num?)?.toDouble() ?? 0,
            existing: args['existing'] as MilestoneItem?,
          ),
        );

      case AppRoutes.milestonePlan:
        final project = settings.arguments as ProjectItem;
        return MaterialPageRoute(
            builder: (_) => MilestonePlanPage(project: project));

      case AppRoutes.milestonePlanReview:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => MilestonePlanReviewPage(
            project: args['project'] as ProjectItem,
            milestones:
                (args['milestones'] as List).cast<MilestoneItem>(),
          ),
        );

      case AppRoutes.projectCompletion:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ProjectCompletionPage(
            project: args['project'] as ProjectItem,
            milestones:
                (args['milestones'] as List).cast<MilestoneItem>(),
          ),
        );

      case AppRoutes.ratings:
        return MaterialPageRoute(builder: (_) => const ReviewFormPage());

      case AppRoutes.ratingsStats:
        final freelancerId = settings.arguments as String;
        return MaterialPageRoute(
            builder: (_) =>
                FreelancerStatsPage(freelancerId: freelancerId));

      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());

      case AppRoutes.profileEdit:
        return MaterialPageRoute(
            builder: (_) => const EditProfilePage());

      case AppRoutes.changePassword:
        return MaterialPageRoute(
            builder: (_) => const ChangePasswordPage());

      case AppRoutes.userProfile:
        final userId = settings.arguments as String;
        return MaterialPageRoute(
            builder: (_) => FreelancerProfilePage(userId: userId));

      case AppRoutes.emailVerification:
        return MaterialPageRoute(
            builder: (_) => const EmailVerificationScreen());

      case AppRoutes.freelancerRequest:
        return MaterialPageRoute(
            builder: (_) => const FreelancerRequestScreen());

      case AppRoutes.appeal:
        return MaterialPageRoute(builder: (_) => const AppealScreen());

      case AppRoutes.forgotPassword:
        return MaterialPageRoute(
            builder: (_) => const ForgotPasswordPage());

      case AppRoutes.adminUsers:
        return MaterialPageRoute(
            builder: (_) => const AdminUserListScreen());

      case AppRoutes.adminUserDetail:
        final args = settings.arguments;
        final String userId;
        final bool showAccountActions;
        if (args is Map<String, dynamic>) {
          userId = args['userId'] as String;
          showAccountActions = args['showActions'] as bool? ?? true;
        } else {
          userId = args as String;
          showAccountActions = true;
        }
        return MaterialPageRoute(
            builder: (_) => AdminUserDetailScreen(
                userId: userId, showAccountActions: showAccountActions));

      case AppRoutes.adminRequests:
        return MaterialPageRoute(
            builder: (_) => const AdminFreelancerRequestsScreen());

      // ── Payment Module ─────────────────────────────────────────────────────
      case AppRoutes.paymentCheckout:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            project: args['project'] as ProjectItem,
            milestones: (args['milestones'] as List).cast<MilestoneItem>(),
          ),
        );

      case AppRoutes.paymentStatus:
        final project = settings.arguments as ProjectItem;
        return MaterialPageRoute(
            builder: (_) => PaymentStatusScreen(project: project));

      // ── Overdue & Notification Module ──────────────────────────────────────
      case AppRoutes.notifications:
        return MaterialPageRoute(
            builder: (_) => const NotificationsScreen());

      case AppRoutes.overdueDashboard:
        return MaterialPageRoute(
            builder: (_) => const OverdueDashboardScreen());

      // ── Review Module ─────────────────────────────────────────────────────
      case AppRoutes.reviewCreate:
        final project = settings.arguments as ProjectItem;
        return MaterialPageRoute(
            builder: (_) => ReviewCreateEditScreen(project: project));

      case AppRoutes.reviewEdit:
        final review = settings.arguments as ReviewItem;
        return MaterialPageRoute(
            builder: (_) => ReviewCreateEditScreen(review: review));

      case AppRoutes.adminReviews:
        return MaterialPageRoute(
            builder: (_) => const AdminReviewListScreen());

      // ── Chat Module ───────────────────────────────────────────────────────
      case AppRoutes.chatList:
        return MaterialPageRoute(
            builder: (_) => const ChatListScreen());

      case AppRoutes.chatRoom:
        final room = settings.arguments as ChatRoom;
        return MaterialPageRoute(
            builder: (_) => ChatScreen(room: room));

      // ── Dispute Module ─────────────────────────────────────────────────────
      case AppRoutes.disputeCreate:
        final project = settings.arguments as ProjectItem;
        return MaterialPageRoute(
            builder: (_) => DisputeCreateScreen(project: project));

      case AppRoutes.adminDisputeList:
        return MaterialPageRoute(
            builder: (_) => const AdminDisputeListScreen());

      case AppRoutes.adminDisputeReview:
        final dispute = settings.arguments as DisputeRecord;
        return MaterialPageRoute(
            builder: (_) => AdminDisputeReviewScreen(dispute: dispute));

      // ── Job Posting Module ─────────────────────────────────────────────────
      case AppRoutes.jobFeed:
        return MaterialPageRoute(builder: (_) => const JobFeedScreen());

      case AppRoutes.jobDetail:
        final post = settings.arguments as JobPost;
        return MaterialPageRoute(
            builder: (_) => JobDetailScreen(post: post));

      case AppRoutes.jobForm:
        final existing = settings.arguments as JobPost?;
        return MaterialPageRoute(
            builder: (_) => JobFormScreen(existing: existing));

      case AppRoutes.myJobPosts:
        return MaterialPageRoute(builder: (_) => const MyJobPostsScreen());

      // ── Provide Service Module ─────────────────────────────────────────────
      case AppRoutes.serviceFeed:
        return MaterialPageRoute(builder: (_) => const ServiceFeedScreen());

      case AppRoutes.serviceDetail:
        final service = settings.arguments as FreelancerService;
        return MaterialPageRoute(
            builder: (_) => ServiceDetailScreen(service: service));

      case AppRoutes.serviceForm:
        final existing = settings.arguments as FreelancerService?;
        return MaterialPageRoute(
            builder: (_) => ServiceFormScreen(existing: existing));

      case AppRoutes.myServices:
        return MaterialPageRoute(builder: (_) => const MyServicesScreen());

      // ── Portfolio Module ───────────────────────────────────────────────────
      case AppRoutes.portfolioForm:
        final existing = settings.arguments as PortfolioItem?;
        return MaterialPageRoute(
            builder: (_) => PortfolioFormScreen(existing: existing));

      default:
        // Unknown route — could be an OAuth deep-link path that didn't match
        // the guard above, or a genuine bad route. Either way, land safely.
        return MaterialPageRoute(builder: (_) => const WelcomePage());
    }
  }
}
