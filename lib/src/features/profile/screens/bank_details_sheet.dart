import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../state/app_state.dart';
import '../models/profile_user.dart';

/// Modal bottom-sheet that lets a freelancer register or update their
/// Malaysian bank account details for milestone payouts.
///
/// Can be opened from the Profile page OR from the Project Detail page.
/// Use the static [BankDetailsSheet.show] helper for convenience.
class BankDetailsSheet extends StatefulWidget {
  const BankDetailsSheet({super.key, required this.user});
  final ProfileUser user;

  /// Shows the sheet as a modal bottom-sheet.
  static Future<void> show(BuildContext context, ProfileUser user) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BankDetailsSheet(user: user),
    );
  }

  @override
  State<BankDetailsSheet> createState() => _BankDetailsSheetState();
}

class _BankDetailsSheetState extends State<BankDetailsSheet> {
  static const _banks = [
    'Maybank', 'CIMB Bank', 'Public Bank', 'RHB Bank',
    'Hong Leong Bank', 'AmBank', 'Bank Islam', 'Bank Rakyat',
    'BSN', 'OCBC Bank', 'Standard Chartered', 'HSBC Bank',
    'Alliance Bank', 'Affin Bank', 'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  late String? _selectedBank;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _holderCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBank = widget.user.bankName;
    _accountNumberCtrl =
        TextEditingController(text: widget.user.bankAccountNumber ?? '');
    _holderCtrl = TextEditingController(
        text: widget.user.bankAccountHolder ?? widget.user.displayName);
  }

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'bank_name': _selectedBank,
        'bank_account_number': _accountNumberCtrl.text.trim(),
        'bank_account_holder': _holderCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('uid', widget.user.uid);

      // Refresh AppState so the banner and profile update immediately.
      await AppState.instance.reloadCurrentUser();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank account saved! Payouts will be sent here.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.account_balance, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Payout Bank Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Earnings will be transferred to this account after each '
              'approved milestone.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // ── Bank name dropdown ─────────────────────────────────────────
            DropdownButtonFormField<String>(
              value: _selectedBank,
              decoration: const InputDecoration(
                labelText: 'Bank Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              items: _banks
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBank = v),
              validator: (v) =>
                  v == null ? 'Please select your bank' : null,
            ),
            const SizedBox(height: 12),

            // ── Account number ─────────────────────────────────────────────
            TextFormField(
              controller: _accountNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Account Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin_outlined),
                helperText: 'Digits only, 10–16 characters',
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 16,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final cleaned = v?.trim() ?? '';
                if (cleaned.isEmpty) return 'Enter your account number';
                if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
                  return 'Account number must contain digits only';
                }
                if (cleaned.length < 10) {
                  return 'Account number must be at least 10 digits';
                }
                if (cleaned.length > 16) {
                  return 'Account number must be at most 16 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ── Account holder name ────────────────────────────────────────
            TextFormField(
              controller: _holderCtrl,
              decoration: const InputDecoration(
                labelText: 'Account Holder Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
                helperText: 'Must match your bank account name exactly',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                final cleaned = v?.trim() ?? '';
                if (cleaned.isEmpty) return 'Enter account holder name';
                if (cleaned.length < 3) return 'Name is too short';
                if (!RegExp(r"^[a-zA-Z\s'./-]+$").hasMatch(cleaned)) {
                  return 'Name must contain letters only (no numbers)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Bank Account'),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
