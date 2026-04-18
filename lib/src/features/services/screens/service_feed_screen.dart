import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/category_item.dart';
import '../../../state/app_state.dart';
import '../models/freelancer_service.dart';
import '../widgets/service_badges.dart';
import 'my_services_screen.dart';

/// Services tab entry point.
///
/// - **Clients / Admins** — browse-only: see the full searchable service feed,
///   no "My Services" tab and no create FAB.
/// - **Freelancers** — two tabs: "Browse" + "My Services" (Active / Inactive
///   sub-tabs) with a "New Service" FAB on the My Services tab.
class ServiceFeedScreen extends StatelessWidget {
  const ServiceFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isFreelancer =
        AppState.instance.currentUser?.role == UserRole.freelancer;
    return isFreelancer
        ? const _FreelancerServiceFeed()
        : const Scaffold(body: _ServiceBrowseTab());
  }
}

// ── Freelancer two-tab layout ──────────────────────────────────────────────

class _FreelancerServiceFeed extends StatefulWidget {
  const _FreelancerServiceFeed();

  @override
  State<_FreelancerServiceFeed> createState() =>
      _FreelancerServiceFeedState();
}

class _FreelancerServiceFeedState extends State<_FreelancerServiceFeed>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onMyServices = _tabs.index == 1;
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Browse'),
              Tab(text: 'My Services'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _ServiceBrowseTab(),
                MyServicesBody(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: onMyServices
          ? FloatingActionButton.extended(
              heroTag: 'service_feed_fab',
              icon: const Icon(Icons.add),
              label: const Text('New Service'),
              onPressed: () async {
                await Navigator.pushNamed(context, AppRoutes.serviceForm);
                AppState.instance.reloadMyServices();
              },
            )
          : null,
    );
  }
}

// ── Browse tab ─────────────────────────────────────────────────────────────

class _ServiceBrowseTab extends StatefulWidget {
  const _ServiceBrowseTab();

  @override
  State<_ServiceBrowseTab> createState() => _ServiceBrowseTabState();
}

class _ServiceBrowseTabState extends State<_ServiceBrowseTab> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  double? _maxPrice;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await AppState.instance.reloadServices(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      category: _selectedCategory,
      maxPrice: _maxPrice,
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(
        selectedCategory: _selectedCategory,
        maxPrice: _maxPrice,
        onApply: (cat, price) {
          setState(() {
            _selectedCategory = cat;
            _maxPrice = price;
          });
          _refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final services = AppState.instance.services;
        final fromCache = AppState.instance.servicesFromCache;
        final hasFilters = _selectedCategory != null || _maxPrice != null;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              // ── Search bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search services…',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _refresh();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _refresh(),
                          onChanged: (v) {
                            if (v.isEmpty) _refresh();
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: hasFilters,
                        child: IconButton.outlined(
                          icon: const Icon(Icons.tune),
                          tooltip: 'Filter',
                          onPressed: _showFilterSheet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category chip bar ───────────────────────────────────
              SliverToBoxAdapter(
                child: _CategoryChipBar(
                  selected: _selectedCategory,
                  onSelect: (cat) {
                    setState(() => _selectedCategory = cat);
                    _refresh();
                  },
                ),
              ),

              // ── Offline banner ──────────────────────────────────────
              if (fromCache)
                const SliverToBoxAdapter(child: _OfflineBanner()),

              // ── Active filter chips ─────────────────────────────────
              if (hasFilters)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (_selectedCategory != null)
                          Chip(
                            label: Text(
                              AppState.instance.categories
                                  .firstWhere(
                                    (c) => c.id == _selectedCategory,
                                    orElse: () => CategoryItem(
                                        id: _selectedCategory!,
                                        displayName: _selectedCategory!),
                                  )
                                  .displayName,
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _selectedCategory = null);
                              _refresh();
                            },
                          ),
                        if (_maxPrice != null)
                          Chip(
                            label: Text(
                                'Max RM ${NumberFormat('#,##0').format(_maxPrice)}'),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _maxPrice = null);
                              _refresh();
                            },
                          ),
                      ],
                    ),
                  ),
                ),

              // ── Service grid ────────────────────────────────────────
              services.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.design_services_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              hasFilters
                                  ? 'No services match your filters.'
                                  : 'No services available yet.',
                              style:
                                  TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) =>
                              _ServiceCard(service: services[i]),
                          childCount: services.length,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

// ── Category chip bar ──────────────────────────────────────────────────────

class _CategoryChipBar extends StatelessWidget {
  const _CategoryChipBar({required this.selected, required this.onSelect});
  final String? selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final cats = AppState.instance.categories;
    if (cats.isEmpty) return const SizedBox(height: 44);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...cats.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(cat.displayName),
                selected: selected == cat.id,
                onSelected: (v) => onSelect(v ? cat.id : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offline banner ─────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Offline — showing cached services',
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Filter bottom sheet ────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.selectedCategory,
    required this.maxPrice,
    required this.onApply,
  });
  final String? selectedCategory;
  final double? maxPrice;
  final void Function(String?, double?) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _category;
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    if (widget.maxPrice != null) {
      _priceController.text = widget.maxPrice!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filter Services',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _category = null;
                    _priceController.clear();
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Category',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: AppState.instance.categories
                .map((c) => ChoiceChip(
                      label: Text(c.displayName),
                      selected: _category == c.id,
                      onSelected: (v) =>
                          setState(() => _category = v ? c.id : null),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Max Budget (RM)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: 'RM ',
              hintText: 'e.g. 500',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final price = double.tryParse(_priceController.text);
                Navigator.pop(context);
                widget.onApply(_category, price);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Service card ───────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});
  final FreelancerService service;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final thumbnail = service.effectiveThumbnail;
    final isRemote = thumbnail.startsWith('http');
    final isLocal =
        thumbnail.isNotEmpty && !isRemote && File(thumbnail).existsSync();

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.serviceDetail,
        arguments: service,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isRemote)
                    Image.network(thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderThumbnail(category: service.category))
                  else if (isLocal)
                    Image.file(File(thumbnail), fit: BoxFit.cover)
                  else
                    _PlaceholderThumbnail(category: service.category),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: ServiceCategoryBadge(service.category),
                  ),
                ],
              ),
            ),

            // ── Info ─────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service.freelancerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (service.priceDisplay != null) ...[
                          Icon(Icons.attach_money,
                              size: 12, color: colors.primary),
                          Expanded(
                            child: Text(
                              service.priceDisplay!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary),
                            ),
                          ),
                        ] else
                          const Expanded(
                            child: Text(
                              'Price on request',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        if (service.deliveryDisplay != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.schedule_outlined,
                              size: 12, color: Colors.grey.shade500),
                          Text(
                            service.deliveryDisplay!,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderThumbnail extends StatelessWidget {
  const _PlaceholderThumbnail({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.design_services_outlined,
          size: 40,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
