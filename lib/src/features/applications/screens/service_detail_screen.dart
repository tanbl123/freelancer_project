import 'package:flutter/material.dart';
import '../models/models.dart';
import '../../../common_widgets/common_widgets.dart';

class ServiceDetailScreen extends StatelessWidget {
  final ServicePost service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(child: Text(service.owner[0])),
                const SizedBox(width: 12),
                Expanded(child: Text(service.owner)),
                const Icon(Icons.star, color: Colors.amber),
                Text(service.rating.toString()),
              ],
            ),
            const SizedBox(height: 16),
            InfoTile(label: 'Service Price', value: 'RM ${service.price.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            Text(service.description, style: TextStyle(color: Colors.grey.shade800, height: 1.5)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Hire Freelancer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
