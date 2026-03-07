import 'package:flutter/material.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('I will build a modern Flutter mobile UI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 10),
                  Text('From RM 450', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w800)),
                  SizedBox(height: 12),
                  Text('Includes responsive screens, modern cards, profile pages, and marketplace layouts for academic demos.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.share_rounded),
            title: Text('Native social sharing placeholder'),
            subtitle: Text('Advanced feature: share profile or service through WhatsApp, Telegram, or email'),
          ),
        ],
      ),
    );
  }
}
