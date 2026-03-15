import 'package:flutter/material.dart';

class PaymentSimulationScreen extends StatelessWidget {
  const PaymentSimulationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stripe Sandbox Payment', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Milestone: UI Screen Delivery\nAmount: RM 300'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Cardholder name')),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Test card number')),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Expiry'))),
              SizedBox(width: 12),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVV'))),
            ],
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_rounded),
              title: Text('Sandbox only'),
              subtitle: Text('This is a simulated payment success flow for assignment demo'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment token generated successfully')),
              );
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF4F46E5),
            ),
            child: const Text('Process Payment'),
          ),
        ],
      ),
    );
  }
}
