import 'package:flutter/material.dart';

import '../../../state/app_state.dart';
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
          appBar: AppBar(title: const Text('My Projects')),
          body: projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, size: 72, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No projects yet.\nProjects are created when a client accepts an application.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      if (user?.role == 'client') ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/applications'),
                          icon: const Icon(Icons.description),
                          label: const Text('View Applications'),
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

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({required this.project});
  final ProjectItem project;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  int _milestoneCount = 0;
  int _completedMilestones = 0;

  @override
  void initState() {
    super.initState();
    _loadMilestones();
  }

  Future<void> _loadMilestones() async {
    final milestones = await AppState.instance
        .getMilestonesForProject(widget.project.id);
    if (mounted) {
      setState(() {
        _milestoneCount = milestones.length;
        _completedMilestones = milestones
            .where((m) => m.status.name == 'approved' || m.status.name == 'locked')
            .length;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final user = AppState.instance.currentUser;
    final isClient = user?.uid == project.clientId;
    final counterparty =
        isClient ? (project.freelancerName ?? project.freelancerId) : (project.clientName ?? project.clientId);
    final statusColor = _statusColor(project.status);

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.jobTitle ?? 'Project ${project.id.substring(0, 8)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      project.status.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(isClient ? Icons.code : Icons.business,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${isClient ? 'Freelancer' : 'Client'}: $counterparty',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_milestoneCount > 0) ...[
                Row(
                  children: [
                    const Icon(Icons.task_alt, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Milestones: $_completedMilestones/$_milestoneCount completed',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _milestoneCount > 0
                        ? _completedMilestones / _milestoneCount
                        : 0,
                    minHeight: 6,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Complete project button
              if (project.status == 'inProgress' && isClient)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Complete'),
                    onPressed: () => _confirmComplete(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmComplete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Complete Project'),
        content: const Text(
            'Mark this project as completed? This will allow reviews to be submitted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              AppState.instance
                  .updateProjectStatus(widget.project.id, 'completed');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Project marked as completed!')),
              );
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}
