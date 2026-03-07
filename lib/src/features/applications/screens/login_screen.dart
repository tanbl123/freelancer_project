import 'package:flutter/material.dart';

import '../../../common_widgets/common_widgets.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const AppTextField(label: 'Email', icon: Icons.email_outlined),
            const SizedBox(height: 14),
            const AppTextField(label: 'Password', icon: Icons.lock_outline, obscure: true),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: RoleChip(label: 'Client', selected: true)),
                SizedBox(width: 12),
                Expanded(child: RoleChip(label: 'Freelancer')),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainShell()),
                  );
                },
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Login'),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text('Create new account'),
            ),
          ],
        ),
      ),
    );
  }
}
