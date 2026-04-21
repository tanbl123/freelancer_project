import 'package:flutter/material.dart';
import 'package:freelancer_project/src/constants/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/supabase_config.dart';
import 'src/routing/app_router.dart';
import 'src/services/stripe_service.dart';
import 'src/services/supabase_service.dart';
import 'src/state/app_state.dart';

/*
add in your terminal
flutter pub add sqflite
flutter pub add uuid
flutter pub add path_provider
winget install Microsoft.NuGet
flutter pub get
*/


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    realtimeClientOptions: const RealtimeClientOptions(
      // Default is 10 s — emulators and slow connections need more headroom.
      timeout: Duration(seconds: 30),
    ),
  );

  await SupabaseService.instance.initialize(); // init local SQLite cache
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
      // Authenticated users go straight to dashboard.
      // New / logged-out users see the Welcome page first.
      initialRoute:
          AppState.instance.isLoggedIn ? AppRoutes.dashboard : AppRoutes.welcome,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
