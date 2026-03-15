import 'package:flutter/material.dart';
import 'package:freelancer_project/src/features/authentication/screens/login_page.dart';
import 'package:freelancer_project/src/features/dashboard/screens/module_dashboard_page.dart';
import 'package:freelancer_project/src/features/marketplace/screens/marketplace_feed_page.dart';
import 'package:freelancer_project/src/features/profile/screens/profile_page.dart';
import 'package:freelancer_project/src/features/ratings/screens/review_form_page.dart';
import 'package:freelancer_project/src/features/transactions/screens/project_detail_page.dart';

// new screens
import 'package:freelancer_project/src/features/applications/screens/chat_list_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/chat_detail_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/application_form_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/my_posts_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/edit_post_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/milestone_detail_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/deliverable_submission_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/signature_approval_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/payment_simulation_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/review_list_screen.dart';
import 'package:freelancer_project/src/features/applications/screens/edit_review_screen.dart';

class AppRoutes {
  static const login = '/';
  static const dashboard = '/dashboard';
  static const marketplace = '/marketplace';
  static const applications = '/applications';
  static const transactions = '/transactions';
  static const ratings = '/ratings';
  static const profile = '/profile';

  static const chatList = '/chatList';
  static const chatDetail = '/chatDetail';
  static const applicationForm = '/applicationForm';
  static const myPosts = '/myPosts';
  static const editPost = '/editPost';
  static const milestoneDetail = '/milestoneDetail';
  static const deliverableSubmission = '/deliverableSubmission';
  static const signatureApproval = '/signatureApproval';
  static const paymentSimulation = '/paymentSimulation';
  static const reviewList = '/reviewList';
  static const editReview = '/editReview';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) => const ModuleDashboardPage());

      case AppRoutes.marketplace:
        return MaterialPageRoute(builder: (_) => const MarketplaceFeedPage());

      case AppRoutes.applications:
        return MaterialPageRoute(builder: (_) => const ApplicationFormScreen());

      case AppRoutes.transactions:
        return MaterialPageRoute(builder: (_) => const ProjectDetailPage());

      case AppRoutes.ratings:
        return MaterialPageRoute(builder: (_) => const ReviewFormPage());

      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());

      case AppRoutes.chatList:
        return MaterialPageRoute(builder: (_) => const ChatListScreen());

      case AppRoutes.chatDetail:
        return MaterialPageRoute(builder: (_) => const ChatDetailScreen());

      case AppRoutes.applicationForm:
        return MaterialPageRoute(builder: (_) => const ApplicationFormScreen());

      case AppRoutes.myPosts:
        return MaterialPageRoute(builder: (_) => const MyPostsScreen());

      case AppRoutes.editPost:
        return MaterialPageRoute(builder: (_) => const EditPostScreen());

      case AppRoutes.milestoneDetail:
        return MaterialPageRoute(builder: (_) => const MilestoneDetailScreen());

      case AppRoutes.deliverableSubmission:
        return MaterialPageRoute(builder: (_) => const DeliverableSubmissionScreen());

      case AppRoutes.signatureApproval:
        return MaterialPageRoute(builder: (_) => const SignatureApprovalScreen());

      case AppRoutes.paymentSimulation:
        return MaterialPageRoute(builder: (_) => const PaymentSimulationScreen());

      case AppRoutes.reviewList:
        return MaterialPageRoute(builder: (_) => const ReviewListScreen());

      case AppRoutes.editReview:
        return MaterialPageRoute(builder: (_) => const EditReviewScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Route not found'),
            ),
          ),
        );
    }
  }
}