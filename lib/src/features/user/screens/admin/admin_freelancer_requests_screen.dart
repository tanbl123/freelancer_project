import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
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
  }

  void _snack(String? error, String success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? success)));
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final requester = AppState.instance.users
        .cast<ProfileUser?>()
        .firstWhere((u) => u?.uid == req.requesterId, orElse: () => null);
    final displayName = requester?.displayName ?? 'Unknown User';
    final email = requester?.email ?? req.requesterId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: user info + timestamp ──────────────────────────
                  Row(
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
                              Text(displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Text(email,
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline)),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(req.createdAt),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),

                  // ── Motivation (request message) preview ───────────────────
                  if (req.requestMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      req.requestMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.4, fontSize: 13),
                    ),
                  ],

                  // ── Admin note (rejected requests) ─────────────────────────
                  if (req.adminNote != null) ...[
                    const SizedBox(height: 6),
                    Text('Admin note: ${req.adminNote}',
                        style: const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontSize: 13)),
                  ],

                  // ── Quick stats row ────────────────────────────────────────
                  if (requester != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (requester.skillsWithLevel.isNotEmpty)
                          _StatChip(
                              Icons.build_outlined,
                              '${requester.skillsWithLevel.length} skill(s)',
                              Colors.blue),
                        if (requester.workExperiences.isNotEmpty)
                          _StatChip(
                              Icons.work_outline,
                              '${requester.workExperiences.length} job(s)',
                              Colors.green),
                        if (requester.educations.isNotEmpty)
                          _StatChip(
                              Icons.school_outlined,
                              '${requester.educations.length} edu',
                              Colors.purple),
                        if (requester.certifications.isNotEmpty)
                          _StatChip(
                              Icons.verified_outlined,
                              '${requester.certifications.length} cert(s)',
                              Colors.orange),
                        if (requester.resumeUrl != null &&
                            File(requester.resumeUrl!).existsSync())
                          _StatChip(Icons.picture_as_pdf, 'Resume',
                              Colors.red),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // ── View Full Application + action buttons ─────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.article_outlined, size: 16),
                          label: const Text('View Full Application'),
                          style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _ApplicationDetailPage(
                                req: req,
                                requester: requester,
                                showActions: widget.showActions,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (widget.showActions) ...[
                    const SizedBox(height: 8),
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

// ── Small chip showing a count/stat ──────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Full application detail page ──────────────────────────────────────────────

class _ApplicationDetailPage extends StatefulWidget {
  const _ApplicationDetailPage({
    required this.req,
    required this.requester,
    required this.showActions,
  });

  final FreelancerRequest req;
  final ProfileUser? requester;
  final bool showActions;

  @override
  State<_ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<_ApplicationDetailPage> {
  bool _loading = false;

  // ── Approve ──────────────────────────────────────────────────────────────────
  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Approve Request'),
            content: const Text(
                "Approve this freelancer request? The user's role will change to Freelancer."),
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
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    final error =
        await AppState.instance.approveFreelancerRequest(widget.req.id);
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved. User is now a Freelancer.')));
      Navigator.pop(context);
    }
  }

  // ── Reject ───────────────────────────────────────────────────────────────────
  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
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
    if (note == null || !mounted) return;

    setState(() => _loading = true);
    final error =
        await AppState.instance.rejectFreelancerRequest(widget.req.id, note);
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected.')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final r = widget.requester;

    return Scaffold(
      appBar: AppBar(title: const Text('Freelancer Application')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Applicant header ───────────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              backgroundImage: r?.photoUrl != null &&
                                      File(r!.photoUrl!).existsSync()
                                  ? FileImage(File(r.photoUrl!))
                                  : null,
                              child: r?.photoUrl == null ||
                                      !(r?.photoUrl != null &&
                                          File(r!.photoUrl!).existsSync())
                                  ? Text(
                                      (r?.displayName ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r?.displayName ?? 'Unknown',
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold)),
                                  Text(r?.email ?? req.requesterId,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                  if (r?.phone.isNotEmpty == true)
                                    Text(r!.phone,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Submitted: ${_fmt(req.createdAt)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── About / Bio ────────────────────────────────────────
                    _Section(
                      title: 'About',
                      icon: Icons.info_outline,
                      child: Text(
                        r?.bio?.isNotEmpty == true ? r!.bio! : 'Not provided.',
                        style: TextStyle(
                          height: 1.5,
                          color:
                              r?.bio?.isNotEmpty == true ? null : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Skills & Expertise ─────────────────────────────────
                    _Section(
                      title: 'Skills & Expertise',
                      icon: Icons.build_outlined,
                      child: r != null && r.skillsWithLevel.isNotEmpty
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: r.skillsWithLevel
                                  .map((s) => Chip(
                                        label: Text('${s.skill} · ${s.level}'),
                                        visualDensity: VisualDensity.compact,
                                      ))
                                  .toList(),
                            )
                          : const Text('No skills listed.',
                              style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),

                    // ── Work Experience ────────────────────────────────────
                    _Section(
                      title: 'Work Experience',
                      icon: Icons.work_outline,
                      child: r != null && r.workExperiences.isNotEmpty
                          ? Column(
                              children: r.workExperiences
                                  .map((w) => _WorkTile(w))
                                  .toList(),
                            )
                          : const Text('No work experience listed.',
                              style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),

                    // ── Education ──────────────────────────────────────────
                    _Section(
                      title: 'Education',
                      icon: Icons.school_outlined,
                      child: r != null && r.educations.isNotEmpty
                          ? Column(
                              children: r.educations
                                  .map((e) => _EduTile(e))
                                  .toList(),
                            )
                          : const Text('No education listed.',
                              style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),

                    // ── Certifications ─────────────────────────────────────
                    _Section(
                      title: 'Certifications',
                      icon: Icons.verified_outlined,
                      child: r != null && r.certifications.isNotEmpty
                          ? Column(
                              children: r.certifications
                                  .map((c) => _CertTile(c))
                                  .toList(),
                            )
                          : const Text('No certifications listed.',
                              style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),

                    // ── Resume ─────────────────────────────────────────────
                    _Section(
                      title: 'Resume / CV',
                      icon: Icons.picture_as_pdf,
                      child: _ResumeRow(resumeUrl: r?.resumeUrl),
                    ),
                    const SizedBox(height: 12),

                    // ── Portfolio Description ──────────────────────────────
                    _Section(
                      title: 'Portfolio',
                      icon: Icons.collections_bookmark_outlined,
                      child: Text(
                        r?.portfolioDescription?.isNotEmpty == true
                            ? r!.portfolioDescription!
                            : 'Not provided.',
                        style: TextStyle(
                          height: 1.5,
                          color: r?.portfolioDescription?.isNotEmpty == true
                              ? null
                              : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Why Become a Freelancer ────────────────────────────
                    _Section(
                      title: 'Why Become a Freelancer?',
                      icon: Icons.lightbulb_outline,
                      child: Text(
                        req.requestMessage?.isNotEmpty == true
                            ? req.requestMessage!
                            : 'Not provided.',
                        style: TextStyle(
                          height: 1.5,
                          color: req.requestMessage?.isNotEmpty == true
                              ? null
                              : Colors.grey,
                        ),
                      ),
                    ),

                    // ── Admin note (if rejected) ───────────────────────────
                    if (req.adminNote != null) ...[
                      const SizedBox(height: 12),
                      _Section(
                        title: 'Admin Note',
                        icon: Icons.admin_panel_settings_outlined,
                        child: Text(
                          req.adminNote!,
                          style: const TextStyle(
                              fontStyle: FontStyle.italic, height: 1.4),
                        ),
                      ),
                    ],

                    // ── Action buttons ─────────────────────────────────────
                    if (widget.showActions) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                              onPressed: _reject,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14)),
                              onPressed: _approve,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

// ── Reusable section card ─────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Work experience tile ──────────────────────────────────────────────────────

class _WorkTile extends StatelessWidget {
  const _WorkTile(this.w);
  final dynamic w; // WorkExperience

  @override
  Widget build(BuildContext context) {
    final dates = [
      if (w.startDate != null) w.startDate!,
      if (w.currentlyWorkHere) 'Present' else if (w.endDate != null) w.endDate!,
    ].join(' – ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${w.title} @ ${w.company}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (w.employmentType != null || dates.isNotEmpty)
            Text(
              [
                if (w.employmentType != null) w.employmentType!,
                if (dates.isNotEmpty) dates,
              ].join('  ·  '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          if (w.industry != null)
            Text('Industry: ${w.industry}',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
          if (w.description != null) ...[
            const SizedBox(height: 4),
            Text(w.description!,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// ── Education tile ────────────────────────────────────────────────────────────

class _EduTile extends StatelessWidget {
  const _EduTile(this.e);
  final dynamic e; // EducationItem

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.school,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            [
              if (e.degree != null) e.degree!,
              if (e.fieldOfStudy != null) e.fieldOfStudy!,
              e.country,
              if (e.yearOfGraduation != null) '${e.yearOfGraduation}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Certification tile ────────────────────────────────────────────────────────

class _CertTile extends StatelessWidget {
  const _CertTile(this.c);
  final dynamic c; // CertificationItem

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            [
              if (c.issuedBy != null) c.issuedBy!,
              if (c.yearReceived != null) '${c.yearReceived}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Resume row — handles both remote (https) and local file URLs ──────────────

class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.resumeUrl});
  final String? resumeUrl;

  bool get _hasResume {
    if (resumeUrl == null || resumeUrl!.isEmpty) return false;
    if (resumeUrl!.startsWith('http')) return true;        // remote URL
    return File(resumeUrl!).existsSync();                  // local file
  }

  Future<void> _open() async {
    if (resumeUrl == null) return;
    if (resumeUrl!.startsWith('http')) {
      final uri = Uri.parse(resumeUrl!);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } else {
      await OpenFile.open(resumeUrl!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasResume) {
      return const Text('No resume uploaded.',
          style: TextStyle(color: Colors.grey));
    }

    final fileName = resumeUrl!.split('/').last.split('\\').last;

    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tap to open',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
