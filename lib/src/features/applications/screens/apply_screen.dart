import 'package:flutter/material.dart';
import '../../../common_widgets/common_widgets.dart';

class ApplyScreen extends StatelessWidget {
  const ApplyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Proposal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const AppTextField(label: 'Proposal Message', icon: Icons.description_outlined, maxLines: 5),
            const SizedBox(height: 12),
            const AppTextField(label: 'Expected Budget', icon: Icons.payments_outlined),
            const SizedBox(height: 12),
            const AppTextField(label: 'Timeline', icon: Icons.event_note_outlined),
            const SizedBox(height: 16),
            const FeatureBanner(
              title: 'Voice Pitch Recording',
              subtitle: 'Attach up to 30 seconds of voice introduction.',
              icon: Icons.mic_none_outlined,
            ),
            const SizedBox(height: 12),
            const FeatureBanner(
              title: 'Resume Attachment',
              subtitle: 'Client can view linked resume before accepting.',
              icon: Icons.picture_as_pdf_outlined,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Submit Application'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
