import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/marketplace_post.dart';

class MarketplaceFeedPage extends StatelessWidget {
  const MarketplaceFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final posts = AppState.instance.posts;
        final user = AppState.instance.currentUser;
        return Scaffold(
          appBar: AppBar(title: const Text('Marketplace')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreatePostDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Post'),
          ),
          body: posts.isEmpty
              ? const Center(child: Text('No listings yet. Tap + to create one.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isOwner = user?.uid == post.ownerId;
                    return _PostCard(post: post, isOwner: isOwner);
                  },
                ),
        );
      },
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final user = AppState.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _CreatePostDialog(user: user),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.isOwner});

  final MarketplacePost post;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(post.type == PostType.jobRequest ? 'Job' : 'Service'),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(post.description, style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: post.skills
                  .map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(post.ownerName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.attach_money, size: 14, color: Colors.grey),
                Text(
                  'RM ${post.minimumBudget.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  post.deadline.toLocal().toString().split(' ').first,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            if (isOwner) ...[
              const Divider(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () {
                    AppState.instance.deletePost(post.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post deleted.')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreatePostDialog extends StatefulWidget {
  const _CreatePostDialog({required this.user});
  final dynamic user;

  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();
  final _skillsController = TextEditingController();
  PostType _type = PostType.jobRequest;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final user = AppState.instance.currentUser!;
    final post = MarketplacePost(
      id: AppState.instance.newId,
      ownerId: user.uid,
      ownerName: user.displayName,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      minimumBudget: double.tryParse(_budgetController.text) ?? 0,
      deadline: _deadline,
      skills: _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      type: _type,
    );
    AppState.instance.addPost(post);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post created successfully!')),
    );
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Listing'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PostType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: PostType.jobRequest, child: Text('Job Request')),
                    DropdownMenuItem(value: PostType.serviceOffering, child: Text('Service Offering')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? PostType.jobRequest),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  maxLines: 3,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _budgetController,
                  decoration: const InputDecoration(
                    labelText: 'Budget (RM)',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _skillsController,
                  decoration: const InputDecoration(
                    labelText: 'Skills (comma-separated)',
                    border: OutlineInputBorder(),
                    hintText: 'Flutter, Firebase',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Deadline: ${_deadline.toLocal().toString().split(' ').first}'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
