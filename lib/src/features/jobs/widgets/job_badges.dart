import 'package:flutter/material.dart';

import '../../../shared/enums/job_status.dart';
import '../../../shared/models/category_item.dart';
import '../../../state/app_state.dart';

/// Small colored pill showing the category display name (looks up from AppState).
class JobCategoryBadge extends StatelessWidget {
  const JobCategoryBadge(this.category, {super.key});
  final String category;

  String _resolveDisplayName() {
    final cats = AppState.instance.categories;
    final match = cats.cast<CategoryItem?>().firstWhere(
          (c) => c?.id == category,
          orElse: () => null,
        );
    if (match != null) return match.displayName;
    // Fallback: capitalise the slug (e.g. "design" → "Design")
    if (category.isEmpty) return 'Other';
    return category[0].toUpperCase() + category.substring(1);
  }

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
        _resolveDisplayName(),
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
      JobStatus.open      => Colors.green,
      JobStatus.closed    => Colors.orange,
      JobStatus.cancelled => Colors.red,
      JobStatus.deleted   => Colors.grey,
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
