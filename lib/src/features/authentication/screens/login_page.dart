import 'package:flutter/material.dart';

import '../../../state/app_state.dart';
import '../../dashboard/screens/module_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillsController = TextEditingController();
  bool _isRegisterMode = false;
  String _selectedRole = 'freelancer';
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _errorMessage = null);
    final name = _nameController.text.trim();

    if (_isRegisterMode) {
      if (name.isEmpty) {
        setState(() => _errorMessage = 'Please enter your display name.');
        return;
      }
      AppState.instance.register(
        name: name,
        role: _selectedRole,
        bio: _bioController.text.trim(),
        skills: _skillsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
      _goToDashboard();
    } else {
      final error = AppState.instance.login(name);
      if (error != null) {
        setState(() => _errorMessage = error);
      } else {
        _goToDashboard();
      }
    }
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ModuleDashboardPage()),
    );
  }

  void _quickLogin(String name) {
    _nameController.text = name;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Freelancer App')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Icon(Icons.work_outline, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              _isRegisterMode ? 'Create Account' : 'Welcome Back',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Quick login chips
            if (!_isRegisterMode) ...[
              const Text('Quick login (demo users):', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.business, size: 16),
                    label: const Text('Alicia Tan (Client)'),
                    onPressed: () => _quickLogin('Alicia Tan'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.code, size: 16),
                    label: const Text('Tan Boon Leong (Freelancer)'),
                    onPressed: () => _quickLogin('Tan Boon Leong'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: _isRegisterMode ? TextInputAction.next : TextInputAction.done,
              onSubmitted: (_) => _isRegisterMode ? null : _submit(),
            ),

            // Register-only fields
            if (_isRegisterMode) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                items: const [
                  DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
                  DropdownMenuItem(value: 'client', child: Text('Client')),
                ],
                onChanged: (v) => setState(() => _selectedRole = v ?? 'freelancer'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: 'Skills (comma-separated, optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build_outlined),
                  hintText: 'Flutter, Firebase, Dart',
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
              ),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: Text(_isRegisterMode ? 'Register & Enter' : 'Login'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _isRegisterMode = !_isRegisterMode;
                _errorMessage = null;
              }),
              child: Text(_isRegisterMode
                  ? 'Already have an account? Login'
                  : 'New user? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
