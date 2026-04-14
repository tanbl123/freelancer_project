import 'package:flutter/material.dart';
import 'package:freelancer_project/src/constants/app_constants.dart';

import 'src/routing/app_router.dart';
import 'src/services/database_service.dart';
import 'src/services/stripe_service.dart';
import 'src/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();
  await AppState.instance.initialize();
  StripeService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute:
          AppState.instance.isLoggedIn ? AppRoutes.dashboard : AppRoutes.login,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
