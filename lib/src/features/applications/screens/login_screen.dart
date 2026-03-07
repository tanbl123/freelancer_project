import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.workspaces_rounded, size: 38, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome back',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Login once, then the app shows client or freelancer features based on your profile.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              const TextField(decoration: InputDecoration(labelText: 'Email')),
              const SizedBox(height: 16),
              const TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/clientHome'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Login'),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/freelancerHome'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: const Text('Preview Freelancer Mode'),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('No account yet? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
