import 'package:flutter/material.dart';
import 'src/features/applications/screens/login_screen.dart';
import 'src/features/applications/screens/register_screen.dart';
import 'src/features/applications/screens/become_freelancer_screen.dart';
import 'src/features/applications/screens/job_detail_screen.dart';
import 'src/features/applications/screens/service_detail_screen.dart';
import 'src/features/applications/screens/applications_screen.dart';
import 'src/features/applications/screens/milestones_screen.dart';
import 'src/features/applications/screens/dashboard_screen.dart';
import 'src/features/applications/screens/profile_screen.dart';
import 'src/features/applications/screens/rating_screen.dart';
import 'src/features/applications/screens/create_post_screen.dart';
import 'src/features/applications/screens/main_shell.dart';

void main() {
  runApp(const FreelancerMarketplaceApp());
}

class FreelancerMarketplaceApp extends StatelessWidget {
  const FreelancerMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freelancer Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF06B6D4),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/clientHome': (_) => const MainShell(startAsFreelancer: false),
        '/freelancerHome': (_) => const MainShell(startAsFreelancer: true),
        '/becomeFreelancer': (_) => const BecomeFreelancerScreen(),
        '/jobDetail': (_) => const JobDetailScreen(),
        '/serviceDetail': (_) => const ServiceDetailScreen(),
        '/applications': (_) => const ApplicationsScreen(),
        '/milestones': (_) => const MilestonesScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/profile': (_) => const ProfileScreen(isFreelancer: false),
        '/rating': (_) => const RatingScreen(),
        '/createPost': (_) => const CreatePostScreen(),
      },
    );
  }
}
