import 'package:flutter/material.dart';

import '../../../routing/app_router.dart';
import '../../dashboard/screens/module_dashboard_page.dart';

class LoginPage extends StatelessWidget{
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Freelancer Login'
          ),
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Freelancer',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
                height:8,
            ),
            const Text(
              'Use this quick entry to preview each module screen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: 24,
            ),
            FilledButton(
                onPressed: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_)=>const ModuleDashboardPage(),
                    ),
                  );
                },
                child: const Text(
                    'Enter Dashboard'
                ),
            ),
            const SizedBox(
              height: 12,
            ),
            OutlinedButton(
                onPressed: ()=>Navigator.pushNamed(
                    context, AppRoutes.profile
                ),
                child: const Text(
                    'Go to Profile Screen'
                ),
            ),
          ],
        ),
      ),
    );

  }
}