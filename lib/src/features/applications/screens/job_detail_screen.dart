import 'package:flutter/material.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Mobile App UI Design', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 10),
                  Text('RM 800 - RM 1200', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w800)),
                  SizedBox(height: 12),
                  Text('Looking for a freelancer to design a clean mobile app interface with onboarding, job feed, service cards, and profile screens.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.camera_alt_rounded),
            title: Text('Camera capture placeholder'),
            subtitle: Text('Advanced feature: capture live photo proof from the device camera'),
          ),
          const ListTile(
            leading: Icon(Icons.offline_bolt_rounded),
            title: Text('Offline cache placeholder'),
            subtitle: Text('Advanced feature: latest 20 job posts cached locally with SQLite'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/applications'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Apply for this job'),
          ),
        ],
      ),
    );
  }
}
