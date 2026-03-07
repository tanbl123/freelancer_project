import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final bool isFreelancer;
  final VoidCallback? onBecomeFreelancer;
  final VoidCallback? onSwitchToClient;

  const ProfileScreen({
    super.key,
    required this.isFreelancer,
    this.onBecomeFreelancer,
    this.onSwitchToClient,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.person, color: Color(0xFF4F46E5)),
              ),
              title: const Text('Zi Zhang', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(isFreelancer 
                  ? 'Freelancer account • Can switch to client mode' 
                  : 'Client account • Can activate freelancer mode'),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Phone number')),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Bio'), maxLines: 4),
          const SizedBox(height: 24),
          if (!isFreelancer)
            FilledButton(
              onPressed: onBecomeFreelancer,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF4F46E5),
              ),
              child: const Text('Become a Freelancer'),
            )
          else
            FilledButton(
              onPressed: onSwitchToClient,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF4F46E5),
              ),
              child: const Text('Switch to Client Mode'),
            ),
        ],
      ),
    );
  }
}
