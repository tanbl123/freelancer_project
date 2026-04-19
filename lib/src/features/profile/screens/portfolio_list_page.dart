import 'dart:io';

import 'package:flutter/material.dart';

import '../../../routing/app_router.dart';
import '../../../services/supabase_service.dart';
import '../../../state/app_state.dart';
import '../models/portfolio_item.dart';

/// Full-screen portfolio viewer.
///
/// - [isOwner] = true  → freelancer viewing their own portfolio (add/edit/delete)
/// - [isOwner] = false → public view of another freelancer's portfolio (read-only)
class PortfolioListPage extends StatefulWidget {
  const PortfolioListPage({
    super.key,
    required this.freelancerId,
    required this.isOwner,
    this.ownerName,
  });

  final String freelancerId;
  final bool isOwner;

  /// Used in the AppBar title for public view (e.g. "Ali's Portfolio").
  final String? ownerName;

  @override
  State<PortfolioListPage> createState() => _PortfolioListPageState();
}

class _PortfolioListPageState extends State<PortfolioListPage> {
  // For public view we load into local state so we don't overwrite
  // the logged-in freelancer's own portfolio in AppState.
  List<PortfolioItem>? _publicItems;
  bool _loaded = false;

  bool get _isPublic => !widget.isOwner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.isOwner) {
        await AppState.instance.loadPortfolioItems(widget.freelancerId);
      } else {
        final items = await SupabaseService.instance
            .getPortfolioItems(widget.freelancerId);
        if (mounted) setState(() => _publicItems = items);
      }
    } catch (_) {
      if (mounted) setState(() => _publicItems = []);
    }
    if (mounted) setState(() => _loaded = true);
  }

  List<PortfolioItem> get _items =>
      widget.isOwner ? AppState.instance.portfolioItems : (_publicItems ?? []);

  Future<void> _confirmDelete(PortfolioItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Portfolio Item'),
        content: Text('Remove "${item.title}" from your portfolio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final err = await AppState.instance.deletePortfolioItem(item.id);
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isOwner
        ? 'My Portfolio'
        : "${widget.ownerName ?? 'Portfolio'}";

    return ListenableBuilder(
      // Only listen to AppState when viewing own portfolio
      listenable: widget.isOwner ? AppState.instance : _nullNotifier,
      builder: (context, _) {
        final items = _items;

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (widget.isOwner)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add project',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.portfolioForm),
                ),
            ],
          ),
          body: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? _EmptyState(
                      isOwner: widget.isOwner,
                      onAdd: widget.isOwner
                          ? () => Navigator.pushNamed(
                              context, AppRoutes.portfolioForm)
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) => _PortfolioCard(
                        item: items[i],
                        isOwner: widget.isOwner,
                        onEdit: widget.isOwner
                            ? () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.portfolioForm,
                                  arguments: items[i],
                                )
                            : null,
                        onDelete: widget.isOwner
                            ? () => _confirmDelete(items[i])
                            : null,
                      ),
                    ),
          floatingActionButton: widget.isOwner
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Project'),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.portfolioForm),
                )
              : null,
        );
      },
    );
  }
}

// A do-nothing ChangeNotifier so ListenableBuilder works for public view.
final _nullNotifier = _NullNotifier();

class _NullNotifier extends ChangeNotifier {}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isOwner, this.onAdd});
  final bool isOwner;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections_bookmark_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isOwner
                  ? 'No portfolio items yet'
                  : 'This freelancer has no portfolio items yet',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (isOwner && onAdd != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Project'),
                onPressed: onAdd,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Portfolio card (used in the full-list page) ───────────────────────────────

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.item,
    required this.isOwner,
    this.onEdit,
    this.onDelete,
  });
  final PortfolioItem item;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Project image ─────────────────────────────────────────────────
          if (item.imageUrl != null)
            _buildImage(item.imageUrl!)
          else
            Container(
              height: 120,
              color: Colors.grey.shade100,
              child: Center(
                child: Icon(Icons.image_outlined,
                    size: 40, color: Colors.grey.shade300),
              ),
            ),

          // ── Details ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + owner action buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    if (isOwner) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Edit',
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete',
                        onPressed: onDelete,
                      ),
                    ],
                  ],
                ),

                // Duration badge
                if (item.projectDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(item.projectDate!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],

                // Description
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(item.description!,
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                ],

                // Skills chips
                if (item.skills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.skills
                        .map((s) => Chip(
                              label: Text(s,
                                  style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    const height = 200.0;
    if (url.startsWith('http')) {
      return Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(file,
          height: height, width: double.infinity, fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }
}
