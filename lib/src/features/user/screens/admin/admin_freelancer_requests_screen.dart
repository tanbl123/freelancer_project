import 'package:flutter/material.dart';

import '../../../../routing/app_router.dart';
import '../../../../shared/enums/request_status.dart';
import '../../../../state/app_state.dart';
import '../../../profile/models/profile_user.dart';
import '../../models/freelancer_request.dart';

/// Admin-only. Lists all freelancer upgrade requests, defaulting to pending.
class AdminFreelancerRequestsScreen extends StatefulWidget {
  const AdminFreelancerRequestsScreen({super.key});

  @override
  State<AdminFreelancerRequestsScreen> createState() =>
      _AdminFreelancerRequestsScreenState();
}

class _AdminFreelancerRequestsScreenState
    extends State<AdminFreelancerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Load admin data if not already loaded
    AppState.instance.loadAllFreelancerRequests();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppState.instance.isAdmin) {
      return const Center(child: Text('Access denied.'));
    }
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final all = AppState.instance.allFreelancerRequests;

        List<FreelancerRequest> byStatus(RequestStatus s) =>
            all.where((r) => r.status == s).toList();

        return Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: [
                _CountTab('Pending', byStatus(RequestStatus.pending).length,
                    Colors.orange),
                _CountTab('Approved', byStatus(RequestStatus.approved).length,
                    Colors.green),
                _CountTab('Rejected', byStatus(RequestStatus.rejected).length,
                    Colors.red),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _RequestList(
                      requests: byStatus(RequestStatus.pending),
                      showActions: true),
                  _RequestList(
                      requests: byStatus(RequestStatus.approved),
                      showActions: false),
                  _RequestList(
                      requests: byStatus(RequestStatus.rejected),
                      showActions: false),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CountTab extends Tab {
  _CountTab(String label, int count, Color color)
      : super(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.requests, required this.showActions});
  final List<FreelancerRequest> requests;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
          child: Text('No requests here.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      itemBuilder: (context, i) =>
          _RequestCard(req: requests[i], showActions: showActions),
    );
  }
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({required this.req, required this.showActions});
  final FreelancerRequest req;
  final bool showActions;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _loading = false;

  Future<void> _approve() async {
    final confirmed = await _confirm(
        'Approve Request',
        'Approve this freelancer request? '
            "The user's role will change to Freelancer.");
    if (!confirmed) return;
    setState(() => _loading = true);
    final error =
        await AppState.instance.approveFreelancerRequest(widget.req.id);
    if (!mounted) return;
    setState(() => _loading = false);
    _snack(error, 'Request approved. User is now a Freelancer.');
  }

  Future<void> _reject() async {
    final note = await _promptNote();
    if (note == null) return;
    setState(() => _loading = true);
    final error =
        await AppState.instance.rejectFreelancerRequest(widget.req.id, note);
    if (!mounted) return;
    setState(() => _loading = false);
    _snack(error, 'Request rejected.');
  }

  Future<bool> _confirm(String title, String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(msg),
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

  Future<String?> _promptNote() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Provide a reason for the applicant',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  void _snack(String? error, String success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? success)));
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: user info + timestamp
                  Builder(builder: (context) {
                    final requester = AppState.instance.users
                        .cast<ProfileUser?>()
                        .firstWhere((u) => u?.uid == req.requesterId,
                            orElse: () => null);
                    final displayName =
                        requester?.displayName ?? 'Unknown User';
                    final email = requester?.email ?? req.requesterId;
                    return Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.adminUserDetail,
                              arguments: {
                                'userId': req.requesterId,
                                'showActions': false,
                              },
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                Text(
                                  email,
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      decoration:
                                          TextDecoration.underline),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(req.createdAt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  if (req.requestMessage != null)
                    Text(req.requestMessage!,
                        style: const TextStyle(height: 1.4)),
                  if (req.portfolioUrl != null) ...[
                    const SizedBox(height: 6),
                    Text('Portfolio: ${req.portfolioUrl}',
                        style: const TextStyle(
                            color: Colors.blue, fontSize: 13)),
                  ],
                  if (req.adminNote != null) ...[
                    const SizedBox(height: 6),
                    Text('Admin note: ${req.adminNote}',
                        style: const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontSize: 13)),
                  ],
                  if (widget.showActions) ...[
                    const Divider(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red),
                            onPressed: _reject,
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                            onPressed: _approve,
                          ),
                        ]),
                  ],
                ],
              ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}
