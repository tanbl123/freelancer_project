import 'package:flutter/material.dart';
import 'client_home_screen.dart';
import 'freelancer_home_screen.dart';
import 'applications_screen.dart';
import 'milestones_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  final bool startAsFreelancer;
  const MainShell({super.key, required this.startAsFreelancer});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late bool isFreelancer;
  int index = 0;

  @override
  void initState() {
    super.initState();
    isFreelancer = widget.startAsFreelancer;
  }

  void goBecomeFreelancer() {
    setState(() {
      isFreelancer = true;
      index = 0;
    });
  }

  void switchToClient() {
    setState(() {
      isFreelancer = false;
      index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      isFreelancer
          ? FreelancerHomeScreen(
              onSwitchToClient: switchToClient,
            )
          : ClientHomeScreen(
              onBecomeFreelancer: goBecomeFreelancer,
            ),
      const ApplicationsScreen(),
      const MilestonesScreen(),
      ProfileScreen(
        isFreelancer: isFreelancer,
        onBecomeFreelancer: goBecomeFreelancer,
        onSwitchToClient: switchToClient,
      ),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: isFreelancer ? 'Work' : 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.mail_outline_rounded),
            selectedIcon: Icon(Icons.mail_rounded),
            label: 'Applications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.task_outlined),
            selectedIcon: Icon(Icons.task_rounded),
            label: 'Projects',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
