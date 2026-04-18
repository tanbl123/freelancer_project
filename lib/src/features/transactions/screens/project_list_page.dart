import 'package:flutter/material.dart';

import '../../../backend/shared/domain_types.dart';
import '../../../state/app_state.dart';
import '../models/milestone_item.dart';
import '../models/project_item.dart';
import 'project_detail_page.dart';

class ProjectListPage extends StatefulWidget {
  const ProjectListPage({super.key});

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> {
  @override
  void initState() {
    super.initState();
    AppState.instance.reloadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.currentUser;
        final projects = AppState.instance.userProjects;

        return Scaffold(
          body: projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open,
                          size: 72, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No projects yet.\n'
                        'Projects are created when a client accepts an application or service order.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      if (user?.role == UserRole.client) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => Navigator.pushNamed(
                              context, '/ra'),
                          icon: const Icon(Icons.description),
                          label: const Text('View Applications & Orders'),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => AppState.instance.reloadProjects(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: projects.length,
                    itemBuilder: (context, index) =>
                        _ProjectCard(project: projects[index]),
                  ),
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({required this.project});
  final ProjectItem project;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  List<MilestoneItem> _milestones = [];

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  Future<void> _loadMilestones() async {
    final milestones = await AppState.instance
        .getMilestonesForProject(widget.project.id);
    if (mounted) {
      setState(() => _milestones = milestones);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final user = AppState.instance.currentUser;
    final isClient = user?.uid == project.clientId;
    final counterparty = isClient
        ? (project.freelancerName ?? project.freelancerId)
        : (project.clientName ?? project.clientId);

    final statusColor = project.status.color;
    final completedCount = _milestones.where((m) => m.isCompleted).length;
    final totalCount = _milestones.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailPage(projectId: project.id),
          ),
        ).then((_) => _loadMilestones()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title + status ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.jobTitle ??
                          'Project ${project.id.substring(0, 8)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      project.status.displayName.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Counterparty
              Row(
                children: [
                  Icon(isClient ? Icons.code : Icons.business,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${isClient ? 'Freelancer' : 'Client'}: $counterparty',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Budget
              if (project.totalBudget != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        size: 14, color: Colors.grey),
                    Text(
                      'RM ${project.totalBudget!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],

              // Milestone progress
              if (totalCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.task_alt,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Milestones: $completedCount/$totalCount',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completedCount / totalCount,
                    minHeight: 6,
                  ),
                ),
              ] else if (project.isPendingStart) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isClient
                        ? 'Awaiting milestone plan from freelancer'
                        : 'Action required: propose milestone plan',
                    style: TextStyle(
                        color: Colors.orange.shade800, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
