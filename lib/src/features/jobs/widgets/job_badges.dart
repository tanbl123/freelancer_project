import 'package:flutter/material.dart';

import '../../../shared/enums/job_status.dart';

/// Small colored pill showing the category name.
class JobCategoryBadge extends StatelessWidget {
  const JobCategoryBadge(this.category, {super.key});
  final String category;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Small colored pill showing the [JobStatus] name.
class JobStatusBadge extends StatelessWidget {
  const JobStatusBadge(this.status, {super.key});
  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      JobStatus.open => Colors.green,
      JobStatus.closed => Colors.orange,
      JobStatus.cancelled => Colors.red,
      JobStatus.deleted => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
