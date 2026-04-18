import 'package:flutter/material.dart';

import '../../../../shared/enums/account_status.dart';
import '../../../../shared/enums/appeal_status.dart';
import '../../../../shared/enums/request_status.dart';
import '../../../../state/app_state.dart';
import '../../../profile/models/profile_user.dart';
import '../../models/appeal.dart';
import '../../models/freelancer_request.dart';

/// Admin-only. Full profile view with ability to change account status,
/// approve/reject freelancer requests, and resolve appeals.
class AdminUserDetailScreen extends StatefulWidget {
  final String userId;
  final bool showAccountActions;
  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    this.showAccountActions = true,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  bool _actionLoading = false;

  // ── Account status actions ─────────────────────────────────────────────────

  Future<void> _setStatus(
      ProfileUser user, AccountStatus newStatus) async {
    final confirmed = await _confirm(
      'Change Account Status',
      'Set ${user.displayName}\'s status to ${newStatus.displayName}?',
    );
    if (!confirmed) return;
    setState(() => _actionLoading = true);
    final error =
        await AppState.instance.setAccountStatus(user.uid, newStatus);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    _showResult(error, 'Status updated to ${newStatus.displayName}.');
  }

  // ── Freelancer request actions ─────────────────────────────────────────────

  Future<void> _approveRequest(FreelancerRequest req) async {
    final confirmed = await _confirm('Approve Request',
        'Approve this freelancer request? The user\'s role will change to Freelancer.');
    if (!confirmed) return;
    setState(() => _actionLoading = true);
    final error =
        await AppState.instance.approveFreelancerRequest(req.id);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    _showResult(error, 'Request approved. User is now a Freelancer.');
  }

  Future<void> _rejectRequest(FreelancerRequest req) async {
    final note = await _promptText(
        'Rejection Reason', 'Provide a reason for rejection:');
    if (note == null) return;
    setState(() => _actionLoading = true);
    final error =
        await AppState.instance.rejectFreelancerRequest(req.id, note);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    _showResult(error, 'Request rejected.');
  }

  // ── Appeal actions ─────────────────────────────────────────────────────────

  Future<void> _approveAppeal(Appeal appeal) async {
    final response = await _promptText(
        'Approve Appeal', 'Write a response for the user:');
    if (response == null) return;
    setState(() => _actionLoading = true);
    final error = await AppState.instance.resolveAppeal(
      appeal.id,
      AppealStatus.approved,
      appeal.appellantId,
      response,
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    _showResult(error, 'Appeal approved. Account reactivated.');
  }

  Future<void> _rejectAppeal(Appeal appeal) async {
    final response = await _promptText(
        'Reject Appeal', 'Write a reason for rejection:');
    if (response == null) return;
    setState(() => _actionLoading = true);
    final error = await AppState.instance.resolveAppeal(
      appeal.id,
      AppealStatus.rejected,
      appeal.appellantId,
      response,
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    _showResult(error, 'Appeal rejected.');
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
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

  Future<String?> _promptText(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
              hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showResult(String? error, String success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? success)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.users
            .where((u) => u.uid == widget.userId)
            .firstOrNull;

        if (user == null) {
          return const Scaffold(
              body: Center(child: Text('User not found.')));
        }

        final requests = AppState.instance.allFreelancerRequests
            .where((r) => r.requesterId == widget.userId)
            .toList();
        final appeals = AppState.instance.allAppeals
            .where((a) => a.appellantId == widget.userId)
            .toList();

        return Scaffold(
          appBar: AppBar(title: Text(user.displayName)),
          body: _actionLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ProfileCard(user: user),
                    if (widget.showAccountActions) ...[
                      const SizedBox(height: 16),
                      _StatusActions(
                          user: user, onSetStatus: _setStatus),
                    ],
                    // Only show freelancer application when accessed from
                    // the Freelancer Requests tab, not from Manage Users.
                    if (!widget.showAccountActions && requests.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...requests.map((r) => _FreelancerRequestCard(
                            req: r,
                            user: user,
                            onApprove: () => _approveRequest(r),
                            onReject: () => _rejectRequest(r),
                          )),
                    ],
                    if (appeals.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...appeals.map((a) => _AppealCard(
                            appeal: a,
                            onApprove: () => _approveAppeal(a),
                            onReject: () => _rejectAppeal(a),
                          )),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final ProfileUser user;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (user.accountStatus) {
      AccountStatus.active => Colors.green,
      AccountStatus.restricted => Colors.orange,
      AccountStatus.pendingVerification => Colors.blue,
      AccountStatus.deactivated => Colors.red,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 28,
                child: Text(user.displayName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 22))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(user.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(user.email,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Row(children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.4))),
                    child: Text(user.accountStatus.displayName,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(user.role.displayName,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ]),
            ),
          ]),
          if (user.bio != null) ...[
            const Divider(height: 20),
            Text(user.bio!,
                style:
                    const TextStyle(color: Colors.grey, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({required this.user, required this.onSetStatus});
  final ProfileUser user;
  final void Function(ProfileUser, AccountStatus) onSetStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Account Actions',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (user.accountStatus != AccountStatus.active)
              OutlinedButton.icon(
                icon: const Icon(Icons.check_circle_outline,
                    color: Colors.green),
                label: const Text('Activate',
                    style: TextStyle(color: Colors.green)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green)),
                onPressed: () =>
                    onSetStatus(user, AccountStatus.active),
              ),
            if (user.accountStatus != AccountStatus.restricted)
              OutlinedButton.icon(
                icon: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange),
                label: const Text('Restrict',
                    style: TextStyle(color: Colors.orange)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange)),
                onPressed: () =>
                    onSetStatus(user, AccountStatus.restricted),
              ),
            if (user.accountStatus != AccountStatus.deactivated)
              OutlinedButton.icon(
                icon: const Icon(Icons.block, color: Colors.red),
                label: const Text('Deactivate',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red)),
                onPressed: () =>
                    onSetStatus(user, AccountStatus.deactivated),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _FreelancerRequestCard extends StatelessWidget {
  const _FreelancerRequestCard({
    required this.req,
    required this.user,
    required this.onApprove,
    required this.onReject,
  });
  final FreelancerRequest req;
  final ProfileUser user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isPending = req.status == RequestStatus.pending;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.work_outline, size: 18),
            const SizedBox(width: 6),
            const Text('Freelancer Application',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            _StatusBadge(req.status),
          ]),
          const Divider(height: 20),

          // ── About / Bio ──────────────────────────────────────────────────
          if (user.bio?.isNotEmpty == true) ...[
            _SectionTitle('About', Icons.info_outline),
            const SizedBox(height: 6),
            Text(user.bio!, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 14),
          ],

          // ── Skills ───────────────────────────────────────────────────────
          if (user.skillsWithLevel.isNotEmpty) ...[
            _SectionTitle('Skills & Expertise', Icons.build_outlined),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: user.skillsWithLevel.map((s) {
                final levelColor = switch (s.level) {
                  'Expert' => Colors.purple,
                  'Intermediate' => Colors.blue,
                  _ => Colors.green,
                };
                return Chip(
                  label: Text('${s.skill}  ·  ${s.level}',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: levelColor.withValues(alpha: 0.08),
                  side: BorderSide(color: levelColor.withValues(alpha: 0.3)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // ── Work Experience ───────────────────────────────────────────────
          if (user.workExperiences.isNotEmpty) ...[
            _SectionTitle('Work Experience', Icons.work_history_outlined),
            const SizedBox(height: 8),
            ...user.workExperiences.map((w) {
              final dates = [
                if (w.startDate != null) w.startDate!,
                if (w.currentlyWorkHere)
                  'Present'
                else if (w.endDate != null)
                  w.endDate!,
              ].join(' – ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(
                          [
                            w.company,
                            if (w.employmentType != null) w.employmentType!,
                            if (dates.isNotEmpty) dates,
                          ].join('  ·  '),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        if (w.industry != null)
                          Text(w.industry!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        if (w.description != null) ...[
                          const SizedBox(height: 4),
                          Text(w.description!,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.4)),
                        ],
                      ],
                    )),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],

          // ── Education ────────────────────────────────────────────────────
          if (user.educations.isNotEmpty) ...[
            _SectionTitle('Education', Icons.school_outlined),
            const SizedBox(height: 8),
            ...user.educations.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.school, size: 15, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.school,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        [
                          if (e.degree != null) e.degree!,
                          if (e.fieldOfStudy != null) e.fieldOfStudy!,
                          e.country,
                          if (e.yearOfGraduation != null)
                            '${e.yearOfGraduation}',
                        ].join('  ·  '),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  )),
                ],
              ),
            )),
            const SizedBox(height: 4),
          ],

          // ── Certifications ───────────────────────────────────────────────
          if (user.certifications.isNotEmpty) ...[
            _SectionTitle('Certifications', Icons.verified_outlined),
            const SizedBox(height: 8),
            ...user.certifications.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.workspace_premium,
                    size: 15, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  [
                    c.name,
                    if (c.issuedBy != null) c.issuedBy!,
                    if (c.yearReceived != null) '${c.yearReceived}',
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: 13),
                )),
              ]),
            )),
            const SizedBox(height: 4),
          ],

          // ── Portfolio Description ────────────────────────────────────────
          if (user.portfolioDescription?.isNotEmpty == true) ...[
            _SectionTitle('Portfolio', Icons.collections_bookmark_outlined),
            const SizedBox(height: 6),
            Text(user.portfolioDescription!,
                style: const TextStyle(height: 1.5)),
            const SizedBox(height: 14),
          ],

          // ── Resume ───────────────────────────────────────────────────────
          if (user.resumeUrl?.isNotEmpty == true) ...[
            _SectionTitle('Resume / CV', Icons.description_outlined),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  user.resumeUrl!.split('/').last,
                  style: const TextStyle(fontSize: 13, color: Colors.blue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 14),
          ],

          // ── Motivation ───────────────────────────────────────────────────
          if (req.requestMessage?.isNotEmpty == true) ...[
            _SectionTitle('Why Become a Freelancer?', Icons.lightbulb_outline),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(req.requestMessage!,
                  style: const TextStyle(height: 1.5)),
            ),
            const SizedBox(height: 14),
          ],

          // ── Admin note (for rejected) ────────────────────────────────────
          if (req.adminNote?.isNotEmpty == true) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined,
                      size: 15, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Admin note: ${req.adminNote}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Action buttons ────────────────────────────────────────────────
          if (isPending) ...[
            const Divider(height: 8),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red),
                onPressed: onReject,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                onPressed: onApprove,
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 6),
      Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary)),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      RequestStatus.pending => (Colors.orange, 'Pending'),
      RequestStatus.approved => (Colors.green, 'Approved'),
      RequestStatus.rejected => (Colors.red, 'Rejected'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _AppealCard extends StatelessWidget {
  const _AppealCard(
      {required this.appeal,
      required this.onApprove,
      required this.onReject});
  final Appeal appeal;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isOpen = appeal.status == AppealStatus.open ||
        appeal.status == AppealStatus.underReview;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.gavel, size: 18),
            const SizedBox(width: 6),
            const Text('Appeal',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 8),
          Text(appeal.reason,
              style: const TextStyle(height: 1.4)),
          if (isOpen) ...[
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red),
                onPressed: onReject,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                onPressed: onApprove,
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
