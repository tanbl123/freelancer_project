import 'package:flutter/material.dart';

class SignatureApprovalScreen extends StatelessWidget {
  const SignatureApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signature Approval', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text('Milestone approval', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Client signs to approve the completed milestone.'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: Text(
                'Digital Signature Pad Placeholder',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/paymentSimulation'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF4F46E5),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
