import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/user/services/user_validator.dart';
import '../../../state/app_state.dart';

/// Three-step password reset screen.
///
/// Step 1 — User enters their email → OTP is sent.
/// Step 2 — User enters the 8-digit OTP → OTP is verified.
/// Step 3 — User enters a new password + confirmation → password is updated.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // ── Step tracking (0 = email, 1 = OTP, 2 = new password) ──────────────────
  int _step = 0;

  // ── Step 1 ─────────────────────────────────────────────────────────────────
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // ── Step 2 ─────────────────────────────────────────────────────────────────
  final List<TextEditingController> _otpControllers =
      List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(8, (_) => FocusNode());
  int _resendSeconds = 30;
  Timer? _resendTimer;

  // ── Step 3 ─────────────────────────────────────────────────────────────────
  final _resetFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // ── Shared state ───────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 8; i++) {
      final idx = i;
      _otpFocusNodes[idx].onKeyEvent = (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _otpControllers[idx].text.isEmpty &&
            idx > 0) {
          _otpControllers[idx - 1].clear();
          _otpFocusNodes[idx - 1].requestFocus();
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
    _emailController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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

  // ── OTP helpers ────────────────────────────────────────────────────────────

  String get _otpCode =>
      _otpControllers.map((c) => c.text).join();

  bool get _isOtpComplete => _otpCode.length == 8;

  void _onDigitChanged(int index, String value) {
    if (value.length == 1) {
      if (index < 7) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    setState(() {});

    // Auto-verify when the last digit is entered.
    if (_isOtpComplete && !_isLoading) _verifyOtp();
  }

  // ── Step 1: Send OTP ───────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final error = await AppState.instance
        .sendPasswordResetOtp(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      setState(() => _step = 1);
      _startResendTimer();
    }
  }

  // ── Step 2: Resend OTP ────────────────────────────────────────────────────

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final error = await AppState.instance
        .sendPasswordResetOtp(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      for (final c in _otpControllers) c.clear();
      _otpFocusNodes[0].requestFocus();
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new reset code has been sent.')),
      );
    } else {
      setState(() => _errorMessage = error);
    }
  }

  // ── Step 2: Verify OTP ────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    if (!_isOtpComplete) {
      setState(() => _errorMessage = 'Please enter the full 8-digit code.');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    final error = await AppState.instance.verifyPasswordResetOtp(
      email: _emailController.text.trim(),
      token: _otpCode,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      for (final c in _otpControllers) c.clear();
      _otpFocusNodes[0].requestFocus();
      setState(() => _errorMessage = error);
    } else {
      // OTP verified — proceed to password reset step
      setState(() { _step = 2; _errorMessage = null; });
    }
  }

  // ── Step 3: Set new password ──────────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final error = await AppState.instance
        .updatePasswordAfterReset(_newPasswordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! Please log in.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: switch (_step) {
          0 => _buildStep1(cs),
          1 => _buildStep2(cs),
          _ => _buildStep3(cs),
        },
      ),
    );
  }

  // ── Step 1 UI: Enter email ─────────────────────────────────────────────────

  Widget _buildStep1(ColorScheme cs) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 40,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.lock_reset, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Reset Your Password',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your registered email address and we will send\n'
            'you an 8-digit reset code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            ],
            onFieldSubmitted: (_) => _sendOtp(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              final emailRegex = RegExp(
                  r'^[\w.+\-]+@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*\.[a-zA-Z]{2,}$');
              if (!emailRegex.hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined),
            label: Text(_isLoading ? 'Sending…' : 'Send Reset Code'),
            onPressed: _isLoading ? null : _sendOtp,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }

  // ── Step 2 UI: Enter & verify OTP ─────────────────────────────────────────

  Widget _buildStep2(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.mark_email_unread_outlined,
              size: 40, color: cs.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Enter Reset Code',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('We sent an 8-digit code to:',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          _emailController.text.trim(),
          textAlign: TextAlign.center,
          style:
              TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
        ),
        const SizedBox(height: 8),
        const Text(
          'The code expires in 10 minutes.\n'
          "Don't see it? Check your spam/junk folder.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 28),

        // OTP boxes — responsive width based on screen size
        LayoutBuilder(
          builder: (context, constraints) {
            const gaps = 8.0 * 7; // 7 gaps between 8 boxes
            final boxWidth =
                ((constraints.maxWidth - gaps) / 8).floorToDouble();
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(8, (i) {
                return Padding(
                  padding: EdgeInsets.only(right: i < 7 ? 8 : 0),
                  child: _OtpBox(
                    controller: _otpControllers[i],
                    focusNode: _otpFocusNodes[i],
                    primary: cs.primary,
                    width: boxWidth,
                    onChanged: (v) => _onDigitChanged(i, v),
                  ),
                );
              }),
            );
          },
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(message: _errorMessage!),
        ],
        const SizedBox(height: 24),

        // Verify button
        FilledButton.icon(
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.verified_outlined),
          label: Text(_isLoading ? 'Verifying…' : 'Verify Code'),
          onPressed: (_isOtpComplete && !_isLoading) ? _verifyOtp : null,
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 12),

        // Resend button
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          label: Text(_resendSeconds > 0
              ? 'Resend Code (${_resendSeconds}s)'
              : 'Resend Code'),
          onPressed:
              (_resendSeconds == 0 && !_isLoading) ? _resendOtp : null,
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _step = 0;
            _errorMessage = null;
            for (final c in _otpControllers) c.clear();
            _resendTimer?.cancel();
          }),
          child: const Text('← Use a different email'),
        ),
      ],
    );
  }

  // ── Step 3 UI: Set new password ───────────────────────────────────────────

  Widget _buildStep3(ColorScheme cs) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 40,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.lock_open_outlined, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Set New Password',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your identity has been verified.\nChoose a strong new password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),

          // New password
          TextFormField(
            controller: _newPasswordController,
            decoration: InputDecoration(
              labelText: 'New Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            obscureText: _obscureNew,
            textInputAction: TextInputAction.next,
            validator: UserValidator.validatePassword,
          ),
          const SizedBox(height: 12),

          // Confirm password
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
            validator: (v) => UserValidator.validateConfirmPassword(
                v, _newPasswordController.text),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(message: _errorMessage!),
          ],
          const SizedBox(height: 24),

          FilledButton.icon(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
            label: Text(_isLoading ? 'Saving…' : 'Save New Password'),
            onPressed: _isLoading ? null : _resetPassword,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: Colors.red.shade800, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

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
        style:
            const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
