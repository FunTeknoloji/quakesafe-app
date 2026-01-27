import 'package:flutter/material.dart';

class DisasterGuideScreen extends StatefulWidget {
  const DisasterGuideScreen({super.key});

  @override
  State<DisasterGuideScreen> createState() => _DisasterGuideScreenState();
}

class _DisasterGuideScreenState extends State<DisasterGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Deprem Rehberi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'ÖNCE'),
            Tab(text: 'SIRASINDA'),
            Tab(text: 'SONRA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          GuideContent(
            title: 'Deprem Öncesi Hazırlık',
            items: [
              'Acil durum çantası hazırlayın.',
              'Evdeki ağır eşyaları sabitleyin.',
              'Aile acil durum planı yapın.',
              'Su ve gıda stoğu yapın (en az 3 günlük).',
              'Elektrik, su ve gaz vanalarının yerini öğrenin.',
            ],
          ),
          GuideContent(
            title: 'Deprem Sırasında Yapılması Gerekenler',
            items: [
              'Sakin olun, panik yapmayın.',
              'Sağlam bir masanın altına girin veya "Çök-Kapan-Tutun" pozisyonu alın.',
              'Pencerelerden ve cam eşyalardan uzak durun.',
              'Merdivenleri veya asansörleri kullanmayın.',
              'Açık alandaysanız, binalardan ve direklerden uzak durun.',
            ],
          ),
          GuideContent(
            title: 'Deprem Sonrası Yapılması Gerekenler',
            items: [
              'Kendinizi ve çevrenizdekileri kontrol edin.',
              'Gaz sızıntısı olmadığından emin olana kadar ateş yakmayın.',
              'Artçı sarsıntılara karşı hazırlıklı olun.',
              'Resmi duyuruları takip edin.',
              'Acil durumlar dışında telefon hatlarını meşgul etmeyin.',
            ],
          ),
        ],
      ),
    );
  }
}

class GuideContent extends StatelessWidget {
  final String title;
  final List<String> items;

  const GuideContent({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => _buildGuideItem(item)).toList(),
      ],
    );
  }

  Widget _buildGuideItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.tealAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
