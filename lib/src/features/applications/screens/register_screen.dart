import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              'Create your account',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'All users start as clients. You can become a freelancer later from profile or settings.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            const TextField(decoration: InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Phone number')),
            const SizedBox(height: 16),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Password')),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/clientHome', (_) => false),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
