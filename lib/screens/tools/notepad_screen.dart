import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotepadScreen extends StatefulWidget {
  const NotepadScreen({super.key});

  @override
  State<NotepadScreen> createState() => _NotepadScreenState();
}

class _NotepadScreenState extends State<NotepadScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _controller.text = prefs.getString('emergency_note') ?? '';
    });
  }

  Future<void> _saveNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_note', _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ACİL DURUM NOTLARI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(onPressed: _saveNote, icon: const Icon(Icons.save_rounded, color: Colors.greenAccent)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: TextField(
            controller: _controller,
            maxLines: null,
            onChanged: (v) => _saveNote(),
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
            decoration: const InputDecoration(
              hintText: 'Buraya acil durum bilgilerinizi, kan grubunuzu veya önemli notlarınızı yazın...',
              hintStyle: TextStyle(color: Colors.white10),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
