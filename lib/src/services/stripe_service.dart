import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:uuid/uuid.dart';

/// Stripe integration (sandbox / test mode).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CONFIGURATION
/// Replace [_testPublishableKey] with your own key from
///   https://dashboard.stripe.com/test/apikeys   (starts with `pk_test_...`)
///
/// PRODUCTION UPGRADE PATH
/// 1. Create a Supabase Edge Function that calls `stripe.paymentIntents.create`
///    with the secret key (never expose the secret key client-side).
/// 2. The Edge Function returns a `client_secret`.
/// 3. In [CheckoutScreen], call:
///      await Stripe.instance.confirmPayment(
///        paymentIntentClientSecret: clientSecret,
///        data: PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
///      );
/// 4. Replace [simulatePaymentIntent] with the real Edge Function call.
/// ─────────────────────────────────────────────────────────────────────────────
class StripeService {
  static const _testPublishableKey =
      'pk_test_51PLACEHOLDER_REPLACE_WITH_YOUR_STRIPE_TEST_KEY';

  static const _uuid = Uuid();

  /// Initialise the Stripe SDK. Called once in [main].
  static void initialize() {
    Stripe.publishableKey = _testPublishableKey;
  }

  // ── Sandbox helpers ────────────────────────────────────────────────────────

  /// Generates a simulated Stripe PaymentMethod token for sandbox mode.
  ///
  /// Used as a fallback when [Stripe.instance.createPaymentMethod] fails
  /// (e.g. the placeholder publishable key is still in place).
  static String generateSimulatedToken() {
    return 'tok_sim_${_uuid.v4().replaceAll('-', '')}';
  }

  /// Simulates a server-side PaymentIntent creation and confirmation.
  ///
  /// **Replace with a real Supabase Edge Function call in production.**
  ///
  /// Returns a fake PaymentIntent ID in the format `pi_test_<uuid>`.
  /// The [amount] (in RM) and [paymentMethodId] are logged for
  /// traceability in the sandbox but have no real effect.
  static String simulatePaymentIntent(
    double amount,
    String paymentMethodId,
  ) {
    // In production this would be:
    //   final response = await supabase.functions.invoke('create-payment-intent',
    //     body: {'amount': (amount * 100).round(), 'currency': 'myr',
    //            'payment_method': paymentMethodId});
    //   return response.data['id'];
    return 'pi_test_${_uuid.v4().replaceAll('-', '')}';
  }

  /// Simulates generating a payout transfer reference.
  ///
  /// In production this would call Stripe Transfers API to send funds
  /// to the freelancer's connected Stripe account.
  static String simulatePayoutTransfer(
    double netAmount,
    String freelancerId,
  ) {
    return 'tr_test_${_uuid.v4().replaceAll('-', '').substring(0, 20)}';
  }

  /// Simulates a refund for unused escrow funds.
  ///
  /// In production this would call `stripe.refunds.create` with the
  /// original PaymentIntent ID and the refund amount.
  static String simulateRefund(
    double refundAmount,
    String paymentIntentId,
  ) {
    return 're_test_${_uuid.v4().replaceAll('-', '').substring(0, 20)}';
  }
}
