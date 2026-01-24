import 'package:flutter/material.dart';
import 'chat_screen.dart';

class OfflineHomeScreen extends StatelessWidget {
  const OfflineHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuakeSafe Çevrimdışı'),
        backgroundColor: Colors.redAccent,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Colors.orangeAccent,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.wifi_off, size: 48, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'İnternet Bağlantısı Yok',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Şu an çevrimdışı moddasınız.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
              icon: const Icon(Icons.chat_bubble),
              label: const Text('Çevrimdışı Sohbet (Bluetooth/Nearby)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _showQuakeInfo(context);
              },
              icon: const Icon(Icons.info),
              label: const Text('Deprem Bilgileri & Talimatları'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const Spacer(),
            const Text(
              'QuakeSafe Çevrimdışı Modu - Güvende Kalın',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuakeInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deprem Anında Ne Yapılmalı?', style: Theme.of(context).textTheme.headlineSmall),
                  const Divider(),
                  const Text('1. ÇÖK-KAPAN-TUTUN: Güvenli bir yerde çökün, başınızı koruyun ve tutunun.'),
                  const Text('2. Merdivenlerden ve asansörlerden uzak durun.'),
                  const Text('3. Pencerelerden ve devrilebilecek eşyalardan uzaklaşın.'),
                  const Text('4. Dışarıdaysanız binalardan, ağaçlardan ve elektrik hatlarından uzak, açık bir alana gidin.'),
                  const SizedBox(height: 20),
                  Text('Deprem Sonrası', style: Theme.of(context).textTheme.headlineSmall),
                  const Divider(),
                  const Text('1. Panik yapmayın, çevrenizi kontrol edin.'),
                  const Text('2. Gaz vanalarını kapatın, elektrik şalterini indirin.'),
                  const Text('3. Artçı sarsıntılara karşı hazırlıklı olun.'),
                  const Text('4. Radyodan veya çevrimdışı sohbetten bilgi almaya çalışın.'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
