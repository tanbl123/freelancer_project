import 'package:flutter/material.dart';

import '../../../common_widgets/common_widgets.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              children: [
                Expanded(child: RoleChip(label: 'Job Request', selected: true)),
                SizedBox(width: 12),
                Expanded(child: RoleChip(label: 'Service Offer')),
              ],
            ),
            const SizedBox(height: 14),
            const AppTextField(label: 'Title', icon: Icons.title_outlined),
            const SizedBox(height: 12),
            const AppTextField(label: 'Description', icon: Icons.notes_outlined, maxLines: 4),
            const SizedBox(height: 12),
            const AppTextField(label: 'Budget / Price', icon: Icons.attach_money_outlined),
            const SizedBox(height: 12),
            const AppTextField(label: 'Deadline Date', icon: Icons.calendar_month_outlined),
            const SizedBox(height: 12),
            const AppTextField(label: 'Required Skills', icon: Icons.psychology_alt_outlined),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Live photo capture for image proof / portfolio preview'),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Publish Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
