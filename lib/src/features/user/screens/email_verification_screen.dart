import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../routing/app_router.dart';
import '../../../state/app_state.dart';

/// Shown immediately after the user submits the registration form.
///
/// The user receives a 6-digit OTP at their email address and enters it here.
/// On success the account becomes Active and the user is taken to the dashboard.
///
/// Navigation contract
/// ───────────────────
/// • Back arrow / Android back → cancels the pending registration and returns
///   to RegisterPage (form data still filled in).
/// • Verify → calls verifySignupOtp; on success pushes dashboard.
/// • Resend OTP → re-sends the email; a 60-second cooldown is enforced.
class EmailVerificationScreen extends StatefulWidget {
  /// The email address the OTP was sent to.
  /// [name], [phone], [photoUrl] are the registration details collected on
  /// the RegisterPage — they are stored here and passed to verifySignupOtp
  /// so the profile row can be created after OTP confirmation.
  const EmailVerificationScreen({
    super.key,
    this.email,
    this.name,
    this.phone,
    this.photoUrl,
  });
  final String? email;
  final String? name;
  final String? phone;
  final String? photoUrl;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // ── OTP box controllers & focus nodes ─────────────────────────────────────
  final List<TextEditingController> _controllers =
      List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(8, (_) => FocusNode());

  // ── State ──────────────────────────────────────────────────────────────────
  bool _verifying = false;
  bool _resending = false;
  String? _errorMessage;

  // Resend cooldown
  int _resendSeconds = 30;
  Timer? _resendTimer;

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _effectiveEmail =>
      widget.email ??
      AppState.instance.currentUser?.email ??
      '';

  String get _otpCode =>
      _controllers.map((c) => c.text).join();

  bool get _isComplete => _otpCode.length == 8;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Wire up backspace-on-empty-box behaviour for each focus node.
    for (int i = 0; i < 8; i++) {
      final idx = i;
      _focusNodes[idx].onKeyEvent = (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[idx].text.isEmpty &&
            idx > 0) {
          // Move to previous box and clear it so the user can re-type.
          _controllers[idx - 1].clear();
          _focusNodes[idx - 1].requestFocus();
          setState(() {});
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  // ── OTP box input handling ─────────────────────────────────────────────────

  void _onDigitChanged(int index, String value) {
    if (value.length == 1) {
      // Advance to next box, or dismiss keyboard on the last box.
      if (index < 7) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      // Box was cleared via soft-keyboard delete — move focus back.
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {}); // Refresh Verify button enabled state.

    // Auto-submit when the last digit is entered.
    if (_isComplete && !_verifying) _verify();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    if (!_isComplete || _verifying) return;
    setState(() { _verifying = true; _errorMessage = null; });

    final error = await AppState.instance.verifySignupOtp(
      email: _effectiveEmail,
      token: _otpCode,
      name: widget.name ?? '',
      phone: widget.phone ?? '',
      photoUrl: widget.photoUrl,
    );

    if (!mounted) return;
    setState(() => _verifying = false);

    if (error != null) {
      // Clear all boxes and show the error so the user can re-enter.
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      setState(() => _errorMessage = error);
    } else {
      // Success — navigate to the main dashboard, clearing back-stack.
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.dashboard, (_) => false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _resending) return;
    setState(() { _resending = true; _errorMessage = null; });

    final error = await AppState.instance
        .resendVerificationEmail(overrideEmail: _effectiveEmail);
    if (!mounted) return;

    setState(() => _resending = false);
    if (error == null) {
      // Clear boxes and restart the cooldown.
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification code has been sent to your email.'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      setState(() => _errorMessage = error);
    }
  }

  Future<void> _onBack() async {
    await AppState.instance.cancelRegistration();
    if (mounted) Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final email = _effectiveEmail;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verify Your Email'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to registration',
            onPressed: _onBack,
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Icon ────────────────────────────────────────────────────
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.mark_email_unread_outlined,
                      size: 48, color: cs.primary),
                ),
                const SizedBox(height: 24),

                // ── Headline ─────────────────────────────────────────────────
                Text(
                  'Enter Verification Code',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'We sent an 8-digit code to:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty ? '—' : email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.primary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The code expires in 10 minutes.\n'
                  "Don't see it? Check your spam/junk folder.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 32),

                // ── 8 OTP boxes (responsive width) ───────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    // constraints.maxWidth = available width inside the
                    // SingleChildScrollView (screen width − 28*2 padding).
                    const gaps = 8.0 * 7; // 7 gaps between 8 boxes
                    final boxWidth =
                        ((constraints.maxWidth - gaps) / 8).floorToDouble();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(8, (i) {
                        return Padding(
                          padding: EdgeInsets.only(right: i < 7 ? 8 : 0),
                          child: _OtpBox(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            primary: cs.primary,
                            width: boxWidth,
                            onChanged: (v) => _onDigitChanged(i, v),
                          ),
                        );
                      }),
                    );
                  },
                ),

                // ── Error message ─────────────────────────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                                color: Colors.red.shade800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // ── Verify button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _verifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_verifying ? 'Verifying…' : 'Verify Code'),
                    onPressed: (_isComplete && !_verifying) ? _verify : null,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Resend button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: _resending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: Text(
                      _resending
                          ? 'Sending…'
                          : _resendSeconds > 0
                              ? 'Resend Code (${_resendSeconds}s)'
                              : 'Resend Code',
                    ),
                    onPressed: (_resendSeconds == 0 && !_resending)
                        ? _resend
                        : null,
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Footer ────────────────────────────────────────────────────
                Text(
                  'Entered the wrong email? Tap ← to go back and correct it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single OTP digit box ──────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.primary,
    required this.width,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color primary;
  final double width;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primary, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
