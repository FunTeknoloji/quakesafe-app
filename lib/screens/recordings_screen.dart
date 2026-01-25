import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<File> _files = [];
  final AudioPlayer _player = AudioPlayer();
  String? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final list = dir.listSync().whereType<File>().where((f) => f.path.contains('call_rec_') || f.path.contains('v_')).toList();
    list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    setState(() => _files = list);
  }

  void _play(String path) async {
    if (_currentlyPlaying == path) {
      await _player.stop();
      setState(() => _currentlyPlaying = null);
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    setState(() => _currentlyPlaying = path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ÇAĞRI KAYITLARI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.black,
      ),
      body: _files.isEmpty
          ? const Center(child: Text('Henüz kayıt yok', style: TextStyle(color: Colors.white38)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _files.length,
              itemBuilder: (context, i) {
                final f = _files[i];
                final name = p.basename(f.path);
                final isPlaying = _currentlyPlaying == f.path;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.mic_rounded, color: isPlaying ? Colors.redAccent : Colors.white24),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(f.lastModifiedSync().toString().split('.')[0], style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(onPressed: () => _play(f.path), icon: Icon(isPlaying ? Icons.stop_circle_rounded : Icons.play_arrow_rounded, color: Colors.white)),
                        IconButton(onPressed: () => Share.shareXFiles([XFile(f.path)]), icon: const Icon(Icons.share_rounded, color: Colors.white38, size: 20)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
