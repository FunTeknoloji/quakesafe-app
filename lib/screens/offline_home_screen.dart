import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/app_state_service.dart';

class OfflineHomeScreen extends StatelessWidget {
  const OfflineHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.warning, size: 100, color: Colors.red),
                ),
              ),
              const SizedBox(height: 30),
              const Card(
                color: Color(0xFF1E1E1E),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.wifi_off, size: 48, color: Colors.redAccent),
                      SizedBox(height: 8),
                      Text(
                        'İnternet Bağlantısı Yok',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Şu an çevrimdışı moddasınız.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoActionCard(
                context,
                'Deprem Bilgileri',
                'Deprem anında ve sonrasında yapılması gerekenler.',
                Icons.info,
                Colors.blueGrey[800]!,
                () => _showQuakeInfo(context),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: AppStateService.allowAutoSwitch,
                builder: (context, allow, child) {
                  if (!allow) {
                    return _buildInfoActionCard(
                      context,
                      'Online Moda Geç',
                      'İnternet bağlantısını kullanmak için geçiş yapın.',
                      Icons.wifi,
                      Colors.blue[900]!,
                      () {
                        AppStateService.allowAutoSwitch.value = true;
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 12),
                const SizedBox(height: 20),
                const Text(
                  'QuakeSafe Çevrimdışı Modu - Güvende Kalın',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuakeInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    const Text('🚨 Deprem Anında Ne Yapılmalı?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const Divider(color: Colors.white24),
                    _buildInfoItem(Icons.back_hand, 'ÇÖK-KAPAN-TUTUN', 'Güvenli bir yerde çökün, başınızı koruyun ve sağlam bir nesneye tutunun.'),
                    _buildInfoItem(Icons.stairs, 'Merdivenler & Asansör', 'Kesinlikle asansör kullanmayın. Merdivenlerden uzak durun.'),
                    _buildInfoItem(Icons.window, 'Pencereler', 'Cam kırıklarından korunmak için pencerelerden uzak durun.'),
                    _buildInfoItem(Icons.landscape, 'Dışarıdaysanız', 'Binalardan, elektrik direklerinden ve ağaçlardan uzak, açık bir alana gidin.'),
                    const SizedBox(height: 30),
                    const Text('✅ Deprem Sonrası', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    const Divider(color: Colors.white24),
                    _buildInfoItem(Icons.check_circle, 'Sakin Olun', 'Panik yapmayın, derin nefes alın ve çevrenizi kontrol edin.'),
                    _buildInfoItem(Icons.fireplace, 'Enerji Kaynakları', 'Gaz vanalarını kapatın, elektrik şalterini indirin.'),
                    _buildInfoItem(Icons.warning_amber, 'Artçı Sarsıntılar', 'Artçı sarsıntılara karşı hazırlıklı olun, hasarlı binalara girmeyin.'),
                    _buildInfoItem(Icons.radio, 'Bilgi Alın', 'Radyo veya çevrimdışı sohbet üzerinden bilgi almaya çalışın.'),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 15, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
