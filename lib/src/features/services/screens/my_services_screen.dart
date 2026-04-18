import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routing/app_router.dart';
import '../../../shared/enums/service_status.dart';
import '../../../state/app_state.dart';
import '../models/freelancer_service.dart';
import '../widgets/service_badges.dart';

/// Standalone screen — wraps [MyServicesBody] with an AppBar and "New Service" FAB.
/// Accessible as a pushed route (e.g. from the profile page).
class MyServicesScreen extends StatelessWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Services')),
      body: const MyServicesBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'my_services_fab',
        icon: const Icon(Icons.add),
        label: const Text('New Service'),
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.serviceForm);
          AppState.instance.reloadMyServices();
        },
      ),
    );
  }
}

/// Embeddable body — used inside [MyServicesScreen] and the "My Services" tab
/// of [ServiceFeedScreen]. Owns its own Active / Inactive sub-TabController.
class MyServicesBody extends StatefulWidget {
  const MyServicesBody({super.key});

  @override
  State<MyServicesBody> createState() => _MyServicesBodyState();
}

class _MyServicesBodyState extends State<MyServicesBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    AppState.instance.reloadMyServices();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Inactive'),
          ],
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) {
              final all = AppState.instance.myServices;
              final active = all
                  .where((s) => s.status == ServiceStatus.active)
                  .toList();
              final inactive = all
                  .where((s) => s.status == ServiceStatus.inactive)
                  .toList();

              return TabBarView(
                controller: _tabs,
                children: [
                  _ServiceList(
                      services: active, emptyLabel: 'No active services.'),
                  _ServiceList(
                      services: inactive, emptyLabel: 'No inactive services.'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Service list ───────────────────────────────────────────────────────────

class _ServiceList extends StatelessWidget {
  const _ServiceList(
      {required this.services, required this.emptyLabel});
  final List<FreelancerService> services;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.design_services_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(emptyLabel,
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _MyServiceCard(service: services[i]),
    );
  }
}

// ── Service card with inline actions ──────────────────────────────────────

class _MyServiceCard extends StatefulWidget {
  const _MyServiceCard({required this.service});
  final FreelancerService service;

  @override
  State<_MyServiceCard> createState() => _MyServiceCardState();
}

class _MyServiceCardState extends State<_MyServiceCard> {
  bool _loading = false;

  Future<void> _action(Future<String?> Function() fn, String successMsg) async {
    setState(() => _loading = true);
    final err = await fn();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? successMsg)));
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final isActive = s.status == ServiceStatus.active;
    final thumbnail = s.effectiveThumbnail;
    final isRemote = thumbnail.startsWith('http');
    final isLocal =
        thumbnail.isNotEmpty && !isRemote && File(thumbnail).existsSync();

    return Card(
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: isRemote
                          ? Image.network(thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _thumbPlaceholder(context))
                          : isLocal
                              ? Image.file(File(thumbnail),
                                  fit: BoxFit.cover)
                              : _thumbPlaceholder(context),
                    ),
                  ),
                  title: Text(
                    s.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ServiceCategoryBadge(s.category),
                          const SizedBox(width: 6),
                          ServiceStatusBadge(s.status),
                        ],
                      ),
                      if (s.priceDisplay != null) ...[
                        const SizedBox(height: 4),
                        Text(s.priceDisplay!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                      if (s.createdAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Created ${DateFormat('d MMM y').format(s.createdAt!)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: true,
                ),

                // ── Quick stats row ──────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _Stat(
                          icon: Icons.visibility_outlined,
                          label: '${s.viewCount} views'),
                      const SizedBox(width: 16),
                      _Stat(
                          icon: Icons.shopping_bag_outlined,
                          label: '${s.orderCount} orders'),
                    ],
                  ),
                ),

                // ── Action buttons ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        onPressed: () async {
                          await Navigator.pushNamed(
                              context, AppRoutes.serviceForm,
                              arguments: s);
                          if (mounted) AppState.instance.reloadMyServices();
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('View'),
                        onPressed: () => Navigator.pushNamed(
                            context, AppRoutes.serviceDetail,
                            arguments: s),
                      ),
                      const Spacer(),
                      if (isActive)
                        IconButton(
                          icon: const Icon(Icons.visibility_off_outlined,
                              color: Colors.orange),
                          tooltip: 'Deactivate',
                          onPressed: () async {
                            final ok = await _confirm(
                                'Deactivate',
                                'Hide "${s.title}" from the feed?');
                            if (!ok) return;
                            _action(
                                () => AppState.instance.deactivateService(
                                    s.id, s.freelancerId),
                                'Service deactivated.');
                          },
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined,
                              color: Colors.green),
                          tooltip: 'Activate',
                          onPressed: () async {
                            final ok = await _confirm(
                                'Activate',
                                'Make "${s.title}" visible again?');
                            if (!ok) return;
                            _action(
                                () => AppState.instance.activateService(
                                    s.id, s.freelancerId),
                                'Service activated.');
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final ok = await _confirm('Delete Service',
                              'Permanently delete "${s.title}"?');
                          if (!ok) return;
                          _action(
                              () => AppState.instance
                                  .removeService(s.id, s.freelancerId),
                              'Service deleted.');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.design_services_outlined, color: Colors.grey),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
