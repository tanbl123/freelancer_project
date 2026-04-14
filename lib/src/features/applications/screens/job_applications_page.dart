import 'package:flutter/material.dart';

class JobApplicationsPage extends StatelessWidget {
  const JobApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'
        ),
      ),
      body: const Padding(
          padding: EdgeInsets.all(16
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Application List UI',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
            ),
            SizedBox(height: 12),
            Text('Placeholder item for: \n Freelancer name\n Proposal summary\n Expected budget\n Status chip'
            ),
          ],
        ),
      ),
    );
  }
}