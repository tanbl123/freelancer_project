import 'package:flutter/material.dart';

import '../features/applications/models/models.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool obscure;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      ),
    );
  }
}

class RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  const RoleChip({super.key, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF345CFF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class FeatureBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const FeatureBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF345CFF), Color(0xFF6E80FF)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  final JobPost job;
  final VoidCallback onTap;
  const JobCard({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(job.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Text('RM ${job.budget.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(job.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: job.skills.map((skill) => Chip(label: Text(skill))).toList()),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text(job.owner[0])),
                const SizedBox(width: 8),
                Expanded(child: Text(job.owner)),
                const Icon(Icons.calendar_month_outlined, size: 16),
                const SizedBox(width: 6),
                Text(job.deadline),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final ServicePost service;
  final VoidCallback onTap;
  const ServiceCard({super.key, required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(service.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(service.rating.toString()),
              ],
            ),
            const SizedBox(height: 8),
            Text(service.description, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text(service.owner[0])),
                const SizedBox(width: 8),
                Expanded(child: Text(service.owner)),
                Text('RM ${service.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const InfoTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (status == 'Pending Review') {
      bg = const Color(0xFFFFF2D9);
    } else if (status == 'In Progress') {
      bg = const Color(0xFFE8EEFF);
    } else {
      bg = const Color(0xFFDFF5E8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
      child: Text(status),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const StatCard({super.key, required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const SettingsRow({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
