import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Stripe integration using Payment Sheet.
///
/// Flow:
/// 1. [presentPaymentSheet] calls the Supabase Edge Function to create a
///    PaymentIntent (server-side, secret key never exposed to the app).
/// 2. The Edge Function returns a `client_secret`.
/// 3. Stripe's native Payment Sheet UI is presented — user enters card details.
/// 4. Stripe confirms the payment and charges the card.
/// 5. Returns the PaymentIntent ID (`pi_xxx`) for our DB records.
class StripeService {
  static const _publishableKey =
      'pk_test_51TNyboGcnylCxTxKpGLGeRnolaskCbuPyxCodqsHyyr5phhpY2eNoSw3rIgXE34QPRBUbqgFxniEskdlhO9jl10j00fAmNUKvl';

  static const _uuid = Uuid();

  /// Initialise the Stripe SDK. Called once in [main].
  static void initialize() {
    Stripe.publishableKey = _publishableKey;
  }

  /// Creates a PaymentIntent via the Edge Function, initialises Stripe's
  /// Payment Sheet, and presents it to the user.
  ///
  /// Returns the PaymentIntent ID (`pi_xxx`) on success.
  /// Throws [StripePaymentException] if the user cancels or payment fails.
  static Future<String> presentPaymentSheet({
    required double amountMyr,
    required String projectId,
    String merchantName = 'FreelanceHub',
  }) async {
    // Step 1 — create PaymentIntent server-side
    final response = await Supabase.instance.client.functions.invoke(
      'create-payment-intent',
      body: {
        'amount_myr': amountMyr,
        'project_id': projectId,
      },
    );

    final data = response.data as Map<String, dynamic>?;
    print('[Stripe] Edge Function response: $data');

    if (data == null || data['error'] != null) {
      final errMsg = data?['error']?.toString() ?? 'Payment failed. Please try again.';
      print('[Stripe] Edge Function error: $errMsg');
      throw StripePaymentException(errMsg);
    }

    final clientSecret = data['client_secret']?.toString();
    final intentId = data['payment_intent_id']?.toString();
    if (clientSecret == null || intentId == null) {
      print('[Stripe] Missing client_secret or payment_intent_id in response');
      throw const StripePaymentException('Invalid response from payment server.');
    }

    // Step 2 — initialise Payment Sheet
    //
    // Card-only mode: no returnURL needed because cards are confirmed inline
    // without any external browser/app redirect.
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: merchantName,
      ),
    );

    // Step 3 — present the native Stripe UI
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        throw const StripePaymentException('Payment was cancelled.');
      }
      throw StripePaymentException(e.error.localizedMessage ?? 'Payment failed.');
    }

    return intentId;
  }

  /// Calls the `onboard-stripe-account` Edge Function to create/retrieve a
  /// Stripe Express account for the freelancer and returns the onboarding URL.
  static Future<String> getOnboardingUrl() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'onboard-stripe-account',
        body: {},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['error'] != null) {
        throw StripePaymentException(
          data?['error']?.toString() ?? 'Failed to create payout account.',
        );
      }
      return data['onboarding_url']?.toString() ?? '';
    } on StripePaymentException {
      rethrow;
    } catch (e) {
      // FunctionException or network error — surface the real message
      final msg = _extractFunctionError(e) ?? 'Failed to create payout account.';
      throw StripePaymentException(msg);
    }
  }

  /// Transfers the net milestone payout to the freelancer's connected Stripe account.
  /// Net = grossAmount × 90% (platform keeps 10%).
  /// Returns the Stripe Transfer ID.
  static Future<String> transferMilestonePayout({
    required String freelancerId,
    required double grossAmountMyr,
    required String paymentIntentId,
    required String milestoneId,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'transfer-milestone-payout',
        body: {
          'freelancer_id': freelancerId,
          'gross_amount_myr': grossAmountMyr,
          'payment_intent_id': paymentIntentId,
          'milestone_id': milestoneId,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['error'] != null) {
        throw StripePaymentException(
          data?['error']?.toString() ?? 'Payout transfer failed.',
        );
      }
      return data['transfer_id']?.toString() ?? generatePayoutReference();
    } on StripePaymentException {
      rethrow;
    } catch (e) {
      final msg = _extractFunctionError(e) ?? 'Payout transfer failed.';
      throw StripePaymentException(msg);
    }
  }

  // ── Extracts a readable message from a Supabase FunctionException ─────────

  static String? _extractFunctionError(Object e) {
    // FunctionException.details may be a Map with an 'error' key,
    // or a raw String, depending on what the Edge Function returned.
    try {
      final details = (e as dynamic).details;
      if (details is Map) return details['error']?.toString();
      if (details is String && details.isNotEmpty) return details;
    } catch (_) {}
    // Fall back to the exception's own toString (trims Dart class prefix)
    final raw = e.toString();
    final colon = raw.indexOf(':');
    return colon >= 0 ? raw.substring(colon + 1).trim() : raw;
  }

  // ── Reference generators for payout / refund DB records ───────────────────

  static String generatePayoutReference() =>
      'po_${_uuid.v4().replaceAll('-', '').substring(0, 20)}';

  static String generateRefundReference() =>
      're_${_uuid.v4().replaceAll('-', '').substring(0, 20)}';
}

/// Thrown when the Stripe payment flow fails or is cancelled.
class StripePaymentException implements Exception {
  const StripePaymentException(this.message);
  final String message;

  @override
  String toString() => message;
}
