import 'package:flutter/material.dart';

import '../features/applications/screens/apply_form_page.dart';
import '../features/welcome/screens/welcome_page.dart';
import '../features/applications/screens/job_applications_page.dart';
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
import '../features/transactions/screens/milestone_form_page.dart';
import '../features/transactions/screens/project_detail_page.dart';
import '../features/transactions/screens/project_list_page.dart';
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
  static const projects = '/projects';
  static const transactions = '/transactions';
  static const transactionsMilestone = '/transactions/milestone';
  static const ratings = '/ratings';
  static const ratingsStats = '/ratings/stats';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const changePassword = '/profile/change-password';
  static const userProfile = '/profile/view'; // public profile viewer
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
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

      case AppRoutes.applicationApply:
        final post = settings.arguments as dynamic;
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
            existing: args['existing'] as MilestoneItem?,
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

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}
