import 'package:flutter/material.dart';

class MarketplaceFeedPage extends StatelessWidget{
  const MarketplaceFeedPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace Feed'
        ),
      ),
      body: const Padding(
          padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Public Job & Service Feed',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(
              height: 12,
            ),
            Text(
                'Placeholder cards for:\n Job title\n Budget\n Deadline\n Client/Freelancer profile'
            ),
          ],
        ),
      ),
    );
  }
}