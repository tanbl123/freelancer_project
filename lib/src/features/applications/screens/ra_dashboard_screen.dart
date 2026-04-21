import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/application_item.dart';
import '../models/service_order.dart';
import 'job_applications_page.dart';
import 'service_orders_page.dart';

/// Request & Application Module — root tab screen.
///
/// Tab labels are role-aware:
///  - **Freelancer**: "My Applications" / "Incoming Orders"
///  - **Client**:     "Applications Received" / "My Orders"
///
/// ## Badge counts
/// Tab badges are driven by a single [ListenableBuilder] wrapping [AppState].
/// Counts update automatically whenever [AppState.notifyListeners] fires —
/// either from a user action (accept/reject) or from the 30-second background
/// polling timer.  No Supabase Realtime subscription is needed here.
class RaDashboardScreen extends StatefulWidget {
  const RaDashboardScreen({super.key});

  @override
  State<RaDashboardScreen> createState() => _RaDashboardScreenState();
}

class _RaDashboardScreenState extends State<RaDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.instance.currentUser;
    final isFreelancer = user?.role == UserRole.freelancer;

    return Scaffold(
      // No AppBar — the main shell already provides one.
      body: Column(
        children: [
          // Use ListenableBuilder so badge counts always match the list
          // (both read from the same in-memory AppState, eliminating the
          // stream vs. in-memory divergence that caused stale badge numbers).
          ListenableBuilder(
            listenable: AppState.instance,
            builder: (_, __) {
              final pendingApps = AppState.instance.userApplications
                  .where((a) => a.status == ApplicationStatus.pending)
                  .length;
              final pendingOrders = AppState.instance.serviceOrders
                  .where((o) => o.status == ServiceOrderStatus.pending)
                  .length;
              return TabBar(
                controller: _tabs,
                tabs: [
                  _TabLabel(
                    label: isFreelancer
                        ? 'My Applications'
                        : 'Applications Received',
                    badgeCount: pendingApps,
                  ),
                  _TabLabel(
                    label: isFreelancer ? 'Incoming Orders' : 'My Orders',
                    badgeCount: pendingOrders,
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                JobApplicationsBody(),
                ServiceOrdersPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab label with optional live badge ────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.badgeCount});
  final String label;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badgeCount > 0) ...[
            const SizedBox(width: 6),
            _CountBadge(badgeCount),
          ],
        ],
      ),
    );
  }
}

// ── Small badge widget ─────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
