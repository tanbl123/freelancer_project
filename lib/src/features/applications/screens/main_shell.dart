import 'package:flutter/material.dart';

import 'applications_screen.dart';
import 'create_post_screen.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'milestones_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;

  final pages = const [
    HomeScreen(),
    ApplicationsScreen(),
    MilestonesScreen(),
    DashboardScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (value) => setState(() => currentIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Apply'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), label: 'Project'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            )
          : null,
    );
  }
}
