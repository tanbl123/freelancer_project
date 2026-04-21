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
/// - Clients see "Contact" + "Order Service" buttons (when the service is live).
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
      'Pause Service',
      'Hide "${_service.title}" from the service listing? '
          'Clients will not be able to find or order it until you reactivate.',
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
    _snack(err, 'Service paused — no longer visible to clients.');
  }

  Future<void> _handleActivate() async {
    final confirmed = await _confirm(
      'Make Service Available',
      'Make "${_service.title}" visible to clients again?',
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
    _snack(err, 'Service is now available to clients.');
  }

  Future<void> _handleDelete() async {
    final confirmed = await _confirm(
      'Remove Service',
      'Permanently remove "${_service.title}"? This cannot be undone.',
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

  Future<void> _handleContact() async {
    final me = AppState.instance.currentUser;
    if (me == null || me.uid == _service.freelancerId) return;
    setState(() => _actionLoading = true);
    final room = await AppState.instance.openDirectChat(_service.freelancerId);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (room != null) {
      Navigator.pushNamed(context, AppRoutes.chatRoom, arguments: room);
    }
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
    final colors = Theme.of(context).colorScheme;

    // Live freelancer name — prevents showing the stale denormalised copy
    // after the provider renames their account.
    final freelancerName =
        AppState.instance.users
            .where((u) => u.uid == _service.freelancerId)
            .firstOrNull
            ?.displayName ??
        _service.freelancerName;

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
                    title: Text('Edit Service'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (isActive)
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: ListTile(
                      leading: Icon(Icons.pause_circle_outline,
                          color: Colors.orange),
                      title: Text('Pause Service',
                          style: TextStyle(color: Colors.orange)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                else if (_service.status == ServiceStatus.inactive)
                  const PopupMenuItem(
                    value: 'activate',
                    child: ListTile(
                      leading: Icon(Icons.play_circle_outline,
                          color: Colors.green),
                      title: Text('Make Available',
                          style: TextStyle(color: Colors.green)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Remove Service',
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
                  // ── Portfolio gallery ────────────────────────────────
                  if (_service.portfolioImageUrls.isNotEmpty)
                    _PortfolioGallery(
                      urls: _service.portfolioImageUrls,
                      currentIndex: _galleryIndex,
                      onPageChanged: (i) =>
                          setState(() => _galleryIndex = i),
                    ),

                  // ── Status banner ────────────────────────────────────
                  if (isClient)
                    _StatusBanner(isLive: _service.isLive),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Badges row ───────────────────────────────
                        Row(
                          children: [
                            ServiceCategoryBadge(_service.category),
                            const SizedBox(width: 6),
                            ServiceStatusBadge(_service.status),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ── Title ────────────────────────────────────
                        Text(
                          _service.title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // ── Freelancer info row ──────────────────────
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  colors.primaryContainer,
                              child: Text(
                                freelancerName.isNotEmpty
                                    ? freelancerName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    freelancerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                  if (_service.createdAt != null)
                                    Text(
                                      'Listed on ${DateFormat('d MMM y').format(_service.createdAt!)}',
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Key stats card ───────────────────────────
                        _StatsCard(service: _service),
                        const SizedBox(height: 20),

                        // ── Description ──────────────────────────────
                        _SectionCard(
                          title: 'About This Service',
                          child: Text(
                            _service.description,
                            style: const TextStyle(
                                height: 1.65, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Tags ─────────────────────────────────────
                        if (_service.tags.isNotEmpty) ...[
                          _SectionCard(
                            title: 'Skills & Expertise',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: _service.tags
                                  .map((t) => Chip(
                                        label: Text(t,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        visualDensity:
                                            VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      // ── Bottom CTA (clients only) ──────────────────────────────────────────
      bottomNavigationBar: !_actionLoading && !_isOwner && isClient
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message'),
                      onPressed: _handleContact,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12)),
                    ),
                    if (_service.isLive) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OrderButton(
                          serviceId: _service.id,
                          onOrder: _handleOrder,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

// ── Status banner ──────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.isLive});
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    if (isLive) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.green.shade50,
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 16, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text(
              'This service is available to order now',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline,
              size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            'This service is temporarily paused by the provider',
            style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Stats card ─────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.service});
  final FreelancerService service;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = <_StatItem>[
      if (service.priceDisplay != null)
        _StatItem(
          icon: Icons.payments_outlined,
          label: 'Price',
          value: service.priceDisplay!,
          valueColor: Colors.green.shade700,
        ),
      if (service.deliveryDisplay != null)
        _StatItem(
          icon: Icons.schedule_outlined,
          label: 'Delivery Time',
          value: service.deliveryDisplay!,
        ),
      _StatItem(
        icon: Icons.visibility_outlined,
        label: 'Total Views',
        value: '${service.viewCount}',
      ),
      _StatItem(
        icon: Icons.shopping_bag_outlined,
        label: 'Orders Completed',
        value: '${service.orderCount}',
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(
                    width: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                colors.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon,
                              size: 16, color: colors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 1),
                              Text(
                                item.value,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: item.valueColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
}

// ── Section card ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
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

  void _openFullScreen(BuildContext context, int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenGallery(
          urls: urls,
          initialIndex: startIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _openFullScreen(context, currentIndex),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              itemCount: urls.length,
              onPageChanged: onPageChanged,
              itemBuilder: (_, i) {
                final url = urls[i];
                final isRemote = url.startsWith('http');
                final isLocal =
                    url.isNotEmpty && !isRemote && File(url).existsSync();
                return Container(
                  color: Colors.black,
                  child: isRemote
                      ? Image.network(url,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const _GalleryPlaceholder())
                      : isLocal
                          ? Image.file(File(url),
                              width: double.infinity, fit: BoxFit.contain)
                          : const _GalleryPlaceholder(),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fullscreen, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Tap to expand',
                    style:
                        TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
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

// ── Full-screen image viewer ───────────────────────────────────────────────

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({
    required this.urls,
    required this.initialIndex,
  });
  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _current;
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.urls.length > 1
            ? Text('${_current + 1} / ${widget.urls.length}')
            : null,
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final url = widget.urls[i];
          final isRemote = url.startsWith('http');
          final isLocal =
              url.isNotEmpty && !isRemote && File(url).existsSync();
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: isRemote
                  ? Image.network(url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                          size: 64))
                  : isLocal
                      ? Image.file(File(url), fit: BoxFit.contain)
                      : const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                          size: 64),
            ),
          );
        },
      ),
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

// ── Order button — reactive, shows "Order Pending" when a live order exists ──
//
// Must be a StatefulWidget with its own AppState listener so it rebuilds the
// moment submitServiceOrder() notifies listeners — no parent rebuild required.

class _OrderButton extends StatefulWidget {
  const _OrderButton({required this.serviceId, required this.onOrder});
  final String serviceId;
  final VoidCallback onOrder;

  @override
  State<_OrderButton> createState() => _OrderButtonState();
}

class _OrderButtonState extends State<_OrderButton> {
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChanged);
    // Ensure the current user's orders are loaded so the check is accurate.
    AppState.instance.reloadServiceOrders();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasActiveOrder {
    final me = AppState.instance.currentUser;
    if (me == null) return false;
    return AppState.instance.serviceOrders.any((o) =>
        o.clientId == me.uid &&
        o.serviceId == widget.serviceId &&
        !o.status.isTerminal);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasActiveOrder) {
      return FilledButton.icon(
        icon: const Icon(Icons.hourglass_top_rounded, size: 18),
        label: const Text('Order Pending'),
        onPressed: null, // disabled
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
        ),
      );
    }

    return FilledButton.icon(
      icon: const Icon(Icons.shopping_cart_outlined, size: 18),
      label: const Text('Order This Service'),
      onPressed: widget.onOrder,
      style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14)),
    );
  }
}
