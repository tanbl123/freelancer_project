import 'package:flutter/material.dart';
import '../../../common_widgets/common_widgets.dart';
import 'main_shell.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            AppTextField(label: 'Full Name', icon: Icons.person_outline),
            SizedBox(height: 12),
            AppTextField(label: 'Email', icon: Icons.email_outlined),
            SizedBox(height: 12),
            AppTextField(label: 'Phone Number', icon: Icons.phone_outlined),
            SizedBox(height: 12),
            AppTextField(label: 'Password', icon: Icons.lock_outline, obscure: true),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: RoleChip(label: 'Client', selected: true)),
                SizedBox(width: 12),
                Expanded(child: RoleChip(label: 'Freelancer')),
              ],
            ),
            SizedBox(height: 12),
            AppTextField(label: 'Skills / Experience (Freelancer)', icon: Icons.auto_awesome_outlined),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: FilledButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
              (_) => false,
            );
          },
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Create Account'),
        ),
      ),
    );
  }
}
