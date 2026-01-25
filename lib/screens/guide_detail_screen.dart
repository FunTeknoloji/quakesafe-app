import 'package:flutter/material.dart';

class GuideDetailScreen extends StatelessWidget {
  final String title;
  final List<GuideContent> content;

  const GuideDetailScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: content.length,
        itemBuilder: (context, index) {
          final item = content[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item.header, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(item.body, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GuideContent {
  final String header;
  final String body;
  GuideContent(this.header, this.body);
}
