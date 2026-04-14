import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:uuid/uuid.dart';

/// Stripe integration (test mode).
///
/// Replace [_testPublishableKey] with your own test key from
/// https://dashboard.stripe.com/test/apikeys (starts with pk_test_...).
///
/// For a full payment flow a server-side PaymentIntent is required.
/// This service provides a simulated token for demo purposes.
class StripeService {
  static const _testPublishableKey =
      'pk_test_51PLACEHOLDER_REPLACE_WITH_YOUR_STRIPE_TEST_KEY';

  static const _uuid = Uuid();

  static void initialize() {
    Stripe.publishableKey = _testPublishableKey;
  }

  /// Generates a simulated Stripe payment token (demo only).
  static String generateSimulatedToken() {
    return 'tok_sim_${_uuid.v4().replaceAll('-', '')}';
  }
}
