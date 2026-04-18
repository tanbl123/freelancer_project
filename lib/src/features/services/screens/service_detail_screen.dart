import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_router.dart';
import '../../../shared/enums/service_status.dart';
import '../../../shared/enums/user_role.dart';
import '../../../state/app_state.dart';
import '../../applications/screens/service_order_form_page.dart';
import '../models/freelancer_service.dart';
import '../widgets/service_badges.dart';

/// Full detail view for a single [FreelancerService].
///
/// - Clients see an "Order Service" button (stub — engagement belongs to the
///   Request & Application Module).
/// - The service owner (freelancer) or an admin sees Edit / Deactivate /
///   Activate / Delete actions via the overflow menu.
class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key, required this.service});
  final FreelancerService service;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late FreelancerService _service;
  bool _actionLoading = false;
  int _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    // Fire-and-forget view count increment (non-critical).
    final user = AppState.instance.currentUser;
    if (user?.uid != _service.freelancerId) {
      AppState.instance.recordServiceView(_service.id);
    }
  }

  bool get _isOwner =>
      AppState.instance.currentUser?.uid == _service.freelancerId;
  bool get _isAdmin => AppState.instance.isAdmin;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handleDeactivate() async {
    final confirmed = await _confirm(
      'Deactivate Service',
      'Hide "${_service.title}" from the public feed? '
          'You can reactivate it at any time.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await AppState.instance
        .deactivateService(_service.id, _service.freelancerId);
    if (!mounted) return;
    setState(() {
      _actionLoading = false;
      if (err == null) {
        _service = _service.copyWith(status: ServiceStatus.inactive);
      }
    });
    _snack(err, 'Service deactivated.');
  }

  Future<void> _handleActivate() async {
    final confirmed = await _confirm(
      'Activate Service',
      'Make "${_service.title}" visible in the service feed again?',
    );
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await AppState.instance
        .activateService(_service.id, _service.freelancerId);
    if (!mounted) return;
    setState(() {
      _actionLoading = false;
      if (err == null) {
        _service = _service.copyWith(status: ServiceStatus.active);
      }
    });
    _snack(err, 'Service activated.');
  }

  Future<void> _handleDelete() async {
    final confirmed = await _confirm(
      'Delete Service',
      'Permanently delete "${_service.title}"? This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await AppState.instance
        .removeService(_service.id, _service.freelancerId);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err == null && mounted) {
      Navigator.pop(context);
    } else {
      _snack(err, '');
    }
  }

  void _handleOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceOrderFormPage(service: _service),
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String? error, String success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? success)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isClient = user?.role == UserRole.client;
    final isActive = _service.status == ServiceStatus.active;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Details'),
        actions: [
          if (_isOwner || _isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    Navigator.pushNamed(context, AppRoutes.serviceForm,
                        arguments: _service);
                    break;
                  case 'deactivate':
                    _handleDeactivate();
                    break;
                  case 'activate':
                    _handleActivate();
                    break;
                  case 'delete':
                    _handleDelete();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (isActive)
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: ListTile(
                      leading: Icon(Icons.visibility_off_outlined,
                          color: Colors.orange),
                      title: Text('Deactivate',
                          style: TextStyle(color: Colors.orange)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                else if (_service.status == ServiceStatus.inactive)
                  const PopupMenuItem(
                    value: 'activate',
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined,
                          color: Colors.green),
                      title: Text('Activate',
                          style: TextStyle(color: Colors.green)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),

      body: _actionLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Portfolio gallery ──────────────────────────────────
                  if (_service.portfolioImageUrls.isNotEmpty) ...[
                    _PortfolioGallery(
                      urls: _service.portfolioImageUrls,
                      currentIndex: _galleryIndex,
                      onPageChanged: (i) =>
                          setState(() => _galleryIndex = i),
                    ),
                  ],

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Status / category badges ───────────────────
                        Row(
                          children: [
                            ServiceCategoryBadge(_service.category),
                            const SizedBox(width: 6),
                            ServiceStatusBadge(_service.status),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Title ──────────────────────────────────────
                        Text(
                          _service.title,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),

                        // ── Freelancer info ────────────────────────────
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'by ${_service.freelancerName}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                            if (_service.createdAt != null) ...[
                              const Text(' · ',
                                  style: TextStyle(color: Colors.grey)),
                              Text(
                                DateFormat('d MMM y')
                                    .format(_service.createdAt!),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Key info tiles ─────────────────────────────
                        _InfoRow(children: [
                          if (_service.priceDisplay != null)
                            _InfoTile(
                              icon: Icons.attach_money,
                              label: 'Price',
                              value: _service.priceDisplay!,
                              valueColor: Colors.green.shade700,
                            ),
                          if (_service.deliveryDisplay != null)
                            _InfoTile(
                              icon: Icons.schedule_outlined,
                              label: 'Delivery',
                              value: _service.deliveryDisplay!,
                            ),
                          _InfoTile(
                            icon: Icons.visibility_outlined,
                            label: 'Views',
                            value: '${_service.viewCount}',
                          ),
                          _InfoTile(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Orders',
                            value: '${_service.orderCount}',
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // ── Description ────────────────────────────────
                        const Text('About this Service',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          _service.description,
                          style: const TextStyle(
                              height: 1.6, fontSize: 14),
                        ),
                        const SizedBox(height: 20),

                        // ── Tags ───────────────────────────────────────
                        if (_service.tags.isNotEmpty) ...[
                          const Text('Skills & Tags',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _service.tags
                                .map((t) => Chip(
                                      label: Text(t),
                                      visualDensity:
                                          VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                        ],

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      // ── Bottom CTA ────────────────────────────────────────────────────────
      bottomNavigationBar: !_actionLoading && isClient && _service.isLive
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Order Service'),
                  onPressed: _handleOrder,
                  style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            )
          : null,
    );
  }
}

// ── Portfolio gallery ──────────────────────────────────────────────────────

class _PortfolioGallery extends StatelessWidget {
  const _PortfolioGallery({
    required this.urls,
    required this.currentIndex,
    required this.onPageChanged,
  });
  final List<String> urls;
  final int currentIndex;
  final void Function(int) onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            itemCount: urls.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) {
              final url = urls[i];
              final isRemote = url.startsWith('http');
              final isLocal =
                  url.isNotEmpty && !isRemote && File(url).existsSync();
              return isRemote
                  ? Image.network(url,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _GalleryPlaceholder())
                  : isLocal
                      ? Image.file(File(url),
                          width: double.infinity, fit: BoxFit.cover)
                      : const _GalleryPlaceholder();
            },
          ),
        ),
        // Dot indicators
        if (urls.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == currentIndex ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == currentIndex
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        // Image counter badge
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentIndex + 1} / ${urls.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 48, color: Colors.grey),
      ),
    );
  }
}

// ── Info tile widgets ──────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 10, children: children);
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: valueColor),
          ),
        ],
      ),
    );
  }
}
