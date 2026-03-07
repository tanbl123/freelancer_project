import 'package:flutter/material.dart';

class ReviewFormPage extends StatelessWidget{
  const ReviewFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Reviews & Ratings'
        ),
      ),
      body: const Padding(
          padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Form',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(
              height: 12,
            ),
            Text(
                'Placeholder widget for:\n Star rating input\n Feedback text\n Submit button\n Rating analytics preview'
            ),
          ],
        ),
      ),
    );
  }
}