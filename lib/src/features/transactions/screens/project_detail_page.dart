import 'package:flutter/material.dart';

class ProjectDetailPage extends StatelessWidget{
  const ProjectDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Project & Milestones'
        ),
      ),
      body: const Padding(
          padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(
              height: 12,
            ),
            Text(
                'Placeholder timeline for:\n Milestone title\n Deadline\n Payment amount\n Approval status'
            ),
          ],
        ),
      ),
    );
  }
}