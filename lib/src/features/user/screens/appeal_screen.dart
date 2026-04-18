import 'package:flutter/material.dart';

import '../../../shared/enums/account_status.dart';
import '../../../shared/enums/appeal_status.dart';
import '../../../state/app_state.dart';

/// Restricted or deactivated users can submit an appeal from this screen.
class AppealScreen extends StatefulWidget {
  const AppealScreen({super.key});

  @override
  State<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends State<AppealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await AppState.instance.submitAppeal(
      _reasonController.text,
      const [], // evidence file upload can be added in a future iteration
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Appeal submitted. An admin will review it.')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.currentUser;
        final appeals = AppState.instance.myAppeals;
        final openAppeal = appeals
            .where((a) =>
                a.status == AppealStatus.open ||
                a.status == AppealStatus.underReview)
            .firstOrNull;

        return Scaffold(
          appBar: AppBar(title: const Text('Submit an Appeal')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status banner
                _StatusBanner(
                    status: user?.accountStatus ?? AccountStatus.restricted),
                const SizedBox(height: 20),

                if (openAppeal != null)
                  _ExistingAppealCard(
                    status: openAppeal.status,
                    adminResponse: openAppeal.adminResponse,
                  )
                else
                  _buildForm(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Explain your situation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _reasonController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'Please explain why you believe your account should be reactivated. '
                  'Provide any relevant context or evidence...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) {
              if (v == null || v.trim().length < 30) {
                return 'Please provide at least 30 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_loading ? 'Submitting...' : 'Submit Appeal'),
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final isDeactivated = status == AccountStatus.deactivated;
    final color = isDeactivated ? Colors.red : Colors.orange;
    final message = isDeactivated
        ? 'Your account has been deactivated. You may submit an appeal below for admin review.'
        : 'Your account has been restricted. Some features are unavailable. Submit an appeal to restore full access.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(isDeactivated ? Icons.block : Icons.warning_amber_rounded,
              color: color.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color.shade800, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ExistingAppealCard extends StatelessWidget {
  const _ExistingAppealCard({required this.status, this.adminResponse});
  final AppealStatus status;
  final String? adminResponse;

  @override
  Widget build(BuildContext context) {
    final isPending = status == AppealStatus.open ||
        status == AppealStatus.underReview;
    final color = isPending ? Colors.blue : Colors.green;
    final icon = isPending ? Icons.hourglass_top : Icons.check_circle;
    final title = isPending ? 'Appeal In Progress' : 'Appeal Reviewed';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'Your appeal has been received and is under review. '
                      'We will notify you of the outcome.'
                  : adminResponse ?? 'Your appeal has been processed.',
              style: const TextStyle(color: Colors.grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
