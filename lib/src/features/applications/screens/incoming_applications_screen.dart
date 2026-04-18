import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/application_item.dart';

/// Client-facing realtime screen — shows all applications received for the
/// client's posted jobs and updates instantly via Supabase Realtime.
///
/// ## How realtime works here
///
/// ```
///  Supabase DB
///     │  INSERT / UPDATE on applications
///     │  where client_id = currentUser.uid
///     ▼
///  Supabase Realtime (.stream)
///     │  emits List<ApplicationItem> — full updated snapshot
///     ▼
///  StreamBuilder  ─────────────────────────────────────────────
///     │  builder receives snapshot.data                        │
///     │                                                        │
///     │  1. Compute _newIds = incoming ids not in _seenIds    │
///     │  2. Render list — new rows get a "NEW" flash badge     │
///     │  3. After 3 s, _seenIds absorbs new ids → badge fades │
///     │                                                        │
///  UI rebuilt (no setState, no polling, no AppState.notify)  │
/// ──────────────────────────────────────────────────────────────
/// ```
///
/// ## Two-tab layout
/// - **Pending** — actionable; client can Accept or Reject.
/// - **All** — full history with status chips.
///
/// ## Navigate to
/// Push with `Navigator.push(context, MaterialPageRoute(builder: (_) =>
/// const IncomingApplicationsScreen()))`.
/// Can also be linked from a specific [JobPost] detail page via the
/// [jobId] filter parameter.
class IncomingApplicationsScreen extends StatefulWidget {
  const IncomingApplicationsScreen({super.key, this.jobId});

  /// When non-null, only applications for this specific job are shown.
  final String? jobId;

  @override
  State<IncomingApplicationsScreen> createState() =>
      _IncomingApplicationsScreenState();
}

class _IncomingApplicationsScreenState
    extends State<IncomingApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 2, vsync: this);

  /// IDs we've already shown to the user — used to detect truly new rows.
  final Set<String> _seenIds = {};

  /// IDs currently showing the "NEW" highlight badge.
  final Set<String> _newIds = {};

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── New-item detection ────────────────────────────────────────────────────

  /// Called each time the stream emits. Updates [_newIds] and schedules
  /// their removal after a short highlight window.
  void _detectNew(List<ApplicationItem> incoming) {
    final incomingIds = incoming.map((a) => a.id).toSet();

    if (_seenIds.isEmpty) {
      // First emission — treat all rows as "already seen" so we don't
      // flash everything on initial load.
      _seenIds.addAll(incomingIds);
      return;
    }

    final fresh = incomingIds.difference(_seenIds);
    if (fresh.isEmpty) return;

    // Mark as seen immediately so the next emission doesn't re-flag them.
    _seenIds.addAll(fresh);

    setState(() => _newIds.addAll(fresh));

    // Remove highlight after 3 seconds.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _newIds.removeAll(fresh));
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _reject(ApplicationItem app) async {
    await AppState.instance
        .updateApplicationStatus(app.id, ApplicationStatus.rejected);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${app.freelancerName}\'s application rejected.'),
        ),
      );
    }
  }

  void _confirmAccept(BuildContext ctx, ApplicationItem app) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Accept Application'),
        content: Text(
          'Accept ${app.freelancerName}\'s proposal?\n\n'
          'All other pending applications for this job will be '
          'automatically rejected and a project will be created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await AppState.instance.acceptApplication(app);
              if (ctx.mounted) {
                if (err != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text(err),
                        backgroundColor: Colors.red),
                  );
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Application accepted — project created!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = AppState.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: widget.jobId != null
            ? const Text('Applications for Job')
            : const Text('Incoming Applications'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: StreamBuilder<List<ApplicationItem>>(
        // This stream is filtered by client_id = uid via ApplicationRepository
        // and backed by Supabase Realtime — it emits automatically on any
        // INSERT or UPDATE on the applications table for this client.
        stream: AppState.instance.applicationsStream,
        initialData: AppState.instance.userApplications,
        builder: (context, snapshot) {
          // Detect and highlight new rows on each emission.
          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _detectNew(snapshot.data!),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error.toString());
          }

          var all = snapshot.data ?? AppState.instance.userApplications;

          // Optional: narrow to a specific job.
          if (widget.jobId != null) {
            all = all.where((a) => a.jobId == widget.jobId).toList();
          }

          final pending = all
              .where((a) => a.status == ApplicationStatus.pending)
              .toList();

          return TabBarView(
            controller: _tab,
            children: [
              // ── Pending tab ──────────────────────────────────────────
              _ApplicationList(
                apps: pending,
                newIds: _newIds,
                emptyIcon: Icons.inbox_outlined,
                emptyMessage: 'No pending applications.',
                onAccept: (a) => _confirmAccept(context, a),
                onReject: _reject,
                showActions: true,
              ),
              // ── All tab ──────────────────────────────────────────────
              _ApplicationList(
                apps: all,
                newIds: _newIds,
                emptyIcon: Icons.description_outlined,
                emptyMessage: 'No applications received yet.',
                onAccept: (a) => _confirmAccept(context, a),
                onReject: _reject,
                showActions: false, // history view — no actions
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Application list ──────────────────────────────────────────────────────────

class _ApplicationList extends StatelessWidget {
  const _ApplicationList({
    required this.apps,
    required this.newIds,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onAccept,
    required this.onReject,
    required this.showActions,
  });

  final List<ApplicationItem> apps;
  final Set<String> newIds;
  final IconData emptyIcon;
  final String emptyMessage;
  final void Function(ApplicationItem) onAccept;
  final Future<void> Function(ApplicationItem) onReject;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: AppState.instance.reloadApplications,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: apps.length,
        itemBuilder: (ctx, i) => _ApplicationCard(
          app: apps[i],
          isNew: newIds.contains(apps[i].id),
          showActions: showActions &&
              apps[i].status == ApplicationStatus.pending,
          onAccept: () => onAccept(apps[i]),
          onReject: () => onReject(apps[i]),
        ),
      ),
    );
  }
}

// ── Application card ──────────────────────────────────────────────────────────

class _ApplicationCard extends StatefulWidget {
  const _ApplicationCard({
    required this.app,
    required this.isNew,
    required this.showActions,
    required this.onAccept,
    required this.onReject,
  });

  final ApplicationItem app;
  final bool isNew;
  final bool showActions;
  final VoidCallback onAccept;
  final Future<void> Function() onReject;

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  bool _busy = false;

  Color get _statusColor {
    switch (widget.app.status) {
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.accepted:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.withdrawn:
        return Colors.grey;
      case ApplicationStatus.convertedToProject:
        return Colors.blue;
    }
  }

  String get _statusLabel =>
      widget.app.status.name.replaceAll('convertedToProject', 'Converted');

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final cs  = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        // "NEW" items get a subtle primary-colour tint that fades after 3 s.
        color: widget.isNew
            ? cs.primaryContainer.withValues(alpha: 0.35)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: _busy
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              cs.primaryContainer,
                          child: Text(
                            app.freelancerName[0].toUpperCase(),
                            style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    app.freelancerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  // "NEW" flash badge
                                  if (widget.isNew) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'NEW',
                                        style: TextStyle(
                                            color: cs.onPrimary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                'Job: ${app.jobId}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        _StatusChip(
                            label: _statusLabel, color: _statusColor),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Proposal message ─────────────────────────────────────
                    Text(
                      app.proposalMessage,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 8),

                    // ── Budget / timeline / date ─────────────────────────────
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        _Detail(
                          icon: Icons.attach_money,
                          label:
                              'RM ${app.expectedBudget.toStringAsFixed(0)}',
                        ),
                        _Detail(
                          icon: Icons.schedule_outlined,
                          label: '${app.timelineDays} days',
                        ),
                        if (app.createdAt != null)
                          _Detail(
                            icon: Icons.calendar_today_outlined,
                            label: DateFormat('d MMM y')
                                .format(app.createdAt!),
                          ),
                      ],
                    ),

                    // ── Actions (Pending only) ───────────────────────────────
                    if (widget.showActions) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red),
                            onPressed: () async {
                              setState(() => _busy = true);
                              await widget.onReject();
                              if (mounted) setState(() => _busy = false);
                            },
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Accept'),
                            onPressed: widget.onAccept,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Failed to load applications.',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: AppState.instance.reloadApplications,
            ),
          ],
        ),
      ),
    );
  }
}
