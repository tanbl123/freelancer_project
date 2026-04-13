import 'package:firebase_core/firebase_core.dart';

/// Centralized Firebase bootstrap.
///
/// Keep [isEnabled] false until `flutterfire configure` has generated
/// `firebase_options.dart` and you wire it below.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool get isEnabled => false;

  static Future<void> initialize() async {
    if (!isEnabled) {
      return;
    }

    await Firebase.initializeApp();
  }
}
