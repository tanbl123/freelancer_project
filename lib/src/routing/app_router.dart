import 'package:flutter/material.dart';
import 'package:freelancer_project/src/features/applications/screens/job_applications_page.dart';
import 'package:freelancer_project/src/features/authentication/screens/login_page.dart';
import 'package:freelancer_project/src/features/marketplace/screens/marketplace_feed_page.dart';
import 'package:freelancer_project/src/features/profile/screens/profile_page.dart';
import 'package:freelancer_project/src/features/ratings/screens/review_form_page.dart';
import 'package:freelancer_project/src/features/transactions/screens/project_detail_page.dart';

class AppRoutes {
  static const login = '/';
  static const marketplace = '/marketplace';
  static const applications = '/applications';
  static const transactions = '/transactions';
  static const ratings = '/ratings';
  static const profile = '/profile';
}

class AppRouter{
  static Route<dynamic> onGenerateRoute(RouteSettings settings){
    switch(settings.name){
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case AppRoutes.marketplace:
        return MaterialPageRoute(builder: (_)=> const MarketplaceFeedPage());
      case AppRoutes.applications:
        return MaterialPageRoute(builder: (_)=> const JobApplicationsPage());
      case AppRoutes.transactions:
        return MaterialPageRoute(builder: (_)=> const ProjectDetailPage());
      case AppRoutes.ratings:
        return MaterialPageRoute(builder: (_)=> const ReviewFormPage());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_)=> const ProfilePage());
      default:
        return MaterialPageRoute(builder: (_)=> const Scaffold(
          body: Center(
            child: Text(
                'Route not found'
            ),
          ),
        ),
      );
    }
  }
}