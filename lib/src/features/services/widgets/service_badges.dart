import 'package:flutter/material.dart';

import '../../../shared/enums/service_status.dart';

/// Small colored pill showing the category name (used for services).
class ServiceCategoryBadge extends StatelessWidget {
  const ServiceCategoryBadge(this.category, {super.key});
  final String category;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
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

/// Small colored pill showing a [ServiceStatus] label.
class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge(this.status, {super.key});
  final ServiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ServiceStatus.active   => Colors.green,
      ServiceStatus.inactive => Colors.orange,
      ServiceStatus.deleted  => Colors.red,
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
