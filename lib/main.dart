import 'package:flutter/material.dart';
import 'package:freelancer_project/src/features/applications/screens/splash_screen.dart';

void main() {
  runApp(const FreelancerApp());
}

class FreelancerApp extends StatelessWidget {
  const FreelancerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Freelancer Marketplace',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF345CFF)),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      ),
      home: const SplashScreen(),
    );
  }
}
