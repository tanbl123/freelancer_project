import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/dev_config.dart';

/// Calls the Abstract Email Validation API to check whether an email address
/// is real and deliverable before letting a user complete registration.
///
/// Docs: https://www.abstractapi.com/api/email-verification-validation-api
///
/// ── How to get your free API key ──────────────────────────────────────────
///  1. Go to https://app.abstractapi.com/api/email-validation/
///  2. Sign up (no credit card needed)
///  3. Copy your API key and paste it below.
/// ──────────────────────────────────────────────────────────────────────────
class EmailValidationService {
  EmailValidationService._();

  // ⚠️  Replace this with your real API key from abstractapi.com
  static const _apiKey = 'd9eeb2340b874fefa6eae1d963f13281';

  static const _baseUrl = 'https://emailreputation.abstractapi.com/v1/';

  /// Validates [email] via the Abstract API.
  ///
  /// Returns:
  ///  - `null`  → email looks good, allow registration to proceed
  ///  - `String` → human-readable error message to show the user
  ///
  /// **Soft-fail policy**: if the API is unreachable, quota is exceeded, or
  /// any unexpected error occurs we return `null` (allow through) so that
  /// developers and users are never blocked by API downtime.
  static Future<String?> validate(String email) async {
    // Skip if disabled in DevConfig or key is placeholder.
    if (!DevConfig.emailValidationEnabled ||
        _apiKey == 'YOUR_ABSTRACT_API_KEY_HERE') return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'api_key': _apiKey,
        'email': email.trim().toLowerCase(),
      });

      debugPrint('[EmailValidation] Calling: $uri');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));

      debugPrint('[EmailValidation] Status: ${response.statusCode}');
      debugPrint('[EmailValidation] Body: ${response.body}');

      // Quota exceeded or server error → soft-fail so users are never blocked
      if (response.statusCode == 429 || response.statusCode >= 500) {
        debugPrint('[EmailValidation] Soft-fail: quota or server error');
        return null;
      }

      // Wrong API key / unauthorised → log it clearly so developer can fix it
      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[EmailValidation] ⚠️  Invalid API key — check _apiKey in EmailValidationService');
        return null; // soft-fail so users aren't blocked by a config mistake
      }

      if (response.statusCode != 200) {
        debugPrint('[EmailValidation] Unexpected status ${response.statusCode} — soft-fail');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // ── Parse deliverability block ──────────────────────────────────────
      final deliverability =
          data['email_deliverability'] as Map<String, dynamic>?;

      if (deliverability == null) {
        debugPrint('[EmailValidation] Unexpected response shape — soft-fail');
        return null;
      }

      final status        = (deliverability['status'] as String? ?? '').toLowerCase();
      final isFormatValid = deliverability['is_format_valid'] as bool? ?? true;
      final isMxValid     = deliverability['is_mx_valid']     as bool? ?? true;
      final isSmtpValid   = deliverability['is_smtp_valid']   as bool? ?? true;

      debugPrint('[EmailValidation] status=$status formatValid=$isFormatValid '
          'mxValid=$isMxValid smtpValid=$isSmtpValid');

      // ── Decision logic ──────────────────────────────────────────────────
      const _invalidMsg = 'This does not appear to be a real email address. '
          'Please enter a valid email address.';

      if (!isFormatValid) return _invalidMsg;
      if (!isMxValid)     return _invalidMsg;

      if (status == 'undeliverable' || (!isSmtpValid && status != 'risky')) {
        return _invalidMsg;
      }

      // "risky" (catch-all domains like Gmail) → allow through.
      // The OTP verification step is the protection for these cases.
      return null;
    } on Exception catch (e) {
      // Network timeout, no internet, SSL error, etc. → soft-fail
      debugPrint('[EmailValidation] Exception (soft-fail): $e');
      return null;
    }
  }
}
