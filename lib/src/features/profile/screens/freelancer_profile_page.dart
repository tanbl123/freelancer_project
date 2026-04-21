import 'dart:io';

import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../routing/app_router.dart';
import '../../../services/supabase_service.dart';
import '../../../state/app_state.dart';
import '../models/portfolio_item.dart';
import '../models/profile_user.dart';
import 'portfolio_list_page.dart';

/// Public profile viewer — shown when a client taps a freelancer name on a
/// post or application card, or when a freelancer taps a client name.
///
/// For freelancers: shows full profile (bio, experience, skills, resume,
/// rating, recent reviews, earnings stats link).
/// For clients: shows limited info (name, role, email, phone only).
class FreelancerProfilePage extends StatelessWidget {
  final String userId;
  const FreelancerProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final ProfileUser? user = AppState.instance.users
            .cast<ProfileUser?>()
            .firstWhere((u) => u?.uid == userId, orElse: () => null);

        if (user == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('User not found.')),
          );
        }

        final isFreelancer = user.role == UserRole.freelancer;
        final reviews = AppState.instance.reviews
            .where((r) => r.freelancerId == userId)
            .toList();
        final colors = Theme.of(context).colorScheme;

        // Who is viewing this profile
        final viewer = AppState.instance.currentUser;
        final viewerIsAdmin = viewer?.role == UserRole.admin;
        final viewerIsOwner = viewer?.uid == userId;

        return Scaffold(
          appBar: AppBar(
            title: Text(user.displayName),
            actions: [
              if (isFreelancer)
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: 'Earnings & Stats',
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.ratingsStats,
                    arguments: userId,
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header card ──────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: colors.primaryContainer,
                          backgroundImage: user.photoUrl != null &&
                                  File(user.photoUrl!).existsSync()
                              ? FileImage(File(user.photoUrl!))
                              : null,
                          child: user.photoUrl == null ||
                                  !File(user.photoUrl!).existsSync()
                              ? Text(
                                  user.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    isFreelancer
                                        ? Icons.code
                                        : Icons.business,
                                    size: 13,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isFreelancer ? 'Freelancer' : 'Client',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                              if (user.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(user.email,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                              if (user.phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(user.phone,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                              if (isFreelancer &&
                                  (user.averageRating ?? 0) > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 15, color: Colors.amber),
                                    Text(
                                      ' ${user.averageRating!.toStringAsFixed(1)}'
                                      ' (${user.totalReviews ?? 0} reviews)',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Freelancer-only sections ─────────────────────────────
                if (isFreelancer) ...[
                  // About / Bio
                  if (user.bio?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'About',
                      icon: Icons.info_outline,
                      child: Text(user.bio!,
                          style: const TextStyle(height: 1.5)),
                    ),
                  ],

                  // Skills — prefer skillsWithLevel, fall back to skills list
                  if (user.skillsWithLevel.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Skills & Expertise',
                      icon: Icons.build_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: user.skillsWithLevel.map((s) {
                          final levelColor = switch (s.level) {
                            'Expert' => Colors.purple,
                            'Intermediate' => Colors.blue,
                            _ => Colors.green,
                          };
                          return Chip(
                            label: Text(s.skill),
                            avatar: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                s.level[0], // B / I / E
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: levelColor),
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),
                  ] else if (user.skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Skills',
                      icon: Icons.build_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: user.skills
                            .map((s) => Chip(
                                  label: Text(s),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ),
                  ],

                  // Work Experience
                  if (user.workExperiences.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Work Experience',
                      icon: Icons.work_outline,
                      child: Column(
                        children: user.workExperiences.map((w) {
                          final dates = [
                            if (w.startDate != null) w.startDate!,
                            if (w.currentlyWorkHere)
                              'Present'
                            else if (w.endDate != null)
                              w.endDate!,
                          ].join(' – ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    w.company,
                                    if (w.employmentType != null)
                                      w.employmentType!,
                                    if (dates.isNotEmpty) dates,
                                  ].join('  ·  '),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                if (w.industry != null) ...[
                                  const SizedBox(height: 2),
                                  Text(w.industry!,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                                if (w.description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(w.description!,
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.4)),
                                ],
                                if (w != user.workExperiences.last)
                                  const Divider(height: 16),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Education
                  if (user.educations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Education',
                      icon: Icons.school_outlined,
                      child: Column(
                        children: user.educations.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.school,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (e.degree != null) e.degree!,
                                    if (e.fieldOfStudy != null)
                                      e.fieldOfStudy!,
                                    e.country,
                                    if (e.yearOfGraduation != null)
                                      '${e.yearOfGraduation}',
                                  ].join('  ·  '),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                if (e != user.educations.last)
                                  const Divider(height: 14),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Certifications
                  if (user.certifications.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Certifications',
                      icon: Icons.verified_outlined,
                      child: Column(
                        children: user.certifications.map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.workspace_premium,
                                    size: 18, color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      if (c.issuedBy != null ||
                                          c.yearReceived != null)
                                        Text(
                                          [
                                            if (c.issuedBy != null) c.issuedBy!,
                                            if (c.yearReceived != null)
                                              '${c.yearReceived}',
                                          ].join('  ·  '),
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Portfolio — compact thumbnail grid + "View All"
                  const SizedBox(height: 12),
                  _PublicPortfolioSection(
                    freelancerId: userId,
                    ownerName: user.displayName,
                  ),

                  // Resume — only visible to admin or the freelancer themselves.
                  // Clients viewing a freelancer's profile do NOT see the CV;
                  // it is only relevant during the freelancer-request review.
                  if ((viewerIsAdmin || viewerIsOwner) &&
                      user.resumeUrl != null &&
                      File(user.resumeUrl!).existsSync()) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Resume / CV',
                      icon: Icons.description_outlined,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(
                          user.resumeUrl!.split('/').last,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: const Text('Tap to open'),
                        dense: true,
                        onTap: () {/* open file if needed */},
                      ),
                    ),
                  ],

                  // Reviews
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Reviews (${reviews.length})',
                    icon: Icons.star_border,
                    child: reviews.isEmpty
                        ? const Text('No reviews yet.',
                            style: TextStyle(color: Colors.grey))
                        : Column(
                            children: reviews.take(5).map((r) {
                              final reviewer = AppState.instance.users
                                  .cast<ProfileUser?>()
                                  .firstWhere(
                                      (u) => u?.uid == r.reviewerId,
                                      orElse: () => null);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < r.stars
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              size: 14,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          reviewer?.displayName ?? 'Client',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(r.comment,
                                        style: const TextStyle(
                                            fontSize: 13, height: 1.4)),
                                    if (r != reviews.last)
                                      const Divider(height: 16),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  // View reviews & rating stats (earnings are private)
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('View Reviews & Stats'),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.ratingsStats,
                        arguments: userId,
                      ),
                    ),
                  ),
                ],

                // ── Client-only: limited info message ────────────────────
                if (!isFreelancer) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: colors.surfaceContainerHighest,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Client profile — contact details shown above.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Public portfolio section (compact thumbnail grid + "View All") ────────────

class _PublicPortfolioSection extends StatefulWidget {
  const _PublicPortfolioSection({
    required this.freelancerId,
    required this.ownerName,
  });
  final String freelancerId;
  final String ownerName;

  @override
  State<_PublicPortfolioSection> createState() =>
      _PublicPortfolioSectionState();
}

class _PublicPortfolioSectionState extends State<_PublicPortfolioSection> {
  List<PortfolioItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await SupabaseService.instance
          .getPortfolioItems(widget.freelancerId);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still loading
    if (_items == null) {
      return const SizedBox(
          height: 48, child: Center(child: CircularProgressIndicator()));
    }
    // No items — hide section entirely
    if (_items!.isEmpty) return const SizedBox.shrink();

    final items = _items!;
    final count = items.length;
    final cs = Theme.of(context).colorScheme;

    return _Section(
      title: 'Portfolio ($count)',
      icon: Icons.collections_bookmark_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-column thumbnail grid (max 6 preview tiles)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: items.take(6).length,
            itemBuilder: (ctx, i) => _PublicPortfolioThumb(item: items[i]),
          ),
          const SizedBox(height: 10),
          // "View All" button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.grid_view, size: 16),
              label: Text(count > 6
                  ? 'View All $count Projects'
                  : 'View All Projects'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PortfolioListPage(
                    freelancerId: widget.freelancerId,
                    isOwner: false,
                    ownerName: widget.ownerName,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicPortfolioThumb extends StatelessWidget {
  const _PublicPortfolioThumb({required this.item});
  final PortfolioItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = item.imageUrl;

    Widget content;
    if (url != null && url.startsWith('http')) {
      content = Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(cs));
    } else if (url != null && File(url).existsSync()) {
      content = Image.file(File(url), fit: BoxFit.cover);
    } else {
      content = _fallback(cs);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              color: Colors.black54,
              child: Text(
                item.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.image_outlined,
            color: cs.onSurface.withValues(alpha: 0.3)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 15,
                    color: Theme.of(context).colorScheme.primary),
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
