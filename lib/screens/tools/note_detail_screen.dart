import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/notes_service.dart';
import '../../services/voice_call_service.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note? note;
  const NoteDetailScreen({super.key, this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  List<String> _attachments = [];
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final VoiceCallService _voiceService = VoiceCallService();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _attachments = List.from(widget.note!.attachments);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Başlık boş olamaz')));
      return;
    }

    final note = Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: _contentController.text,
      date: widget.note?.date ?? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      attachments: _attachments,
    );

    if (widget.note == null) {
      await NotesService.insertNote(note);
    } else {
      await NotesService.updateNote(note);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _attachments.add(image.path));
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _attachments.add(result.files.single.path!));
    }
  }

  Future<void> _toggleSpeech() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _contentController.text = _contentController.text + " " + result.recognizedWords;
            if (result.finalResult) {
              _isListening = false;
            }
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.note == null ? 'YENİ NOT' : 'NOTU DÜZENLE'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check, color: Colors.greenAccent)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'Başlık',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Notunuzu buraya yazın...',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAttachmentsList(),
                ],
              ),
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildAttachmentsList() {
    if (_attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EKLER', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _attachments.length,
          itemBuilder: (context, i) {
            String path = _attachments[i];
            String name = path.split('/').last;
            bool isImage = path.endsWith('.jpg') || path.endsWith('.png') || path.endsWith('.jpeg');
            bool isAudio = path.endsWith('.m4a') || path.endsWith('.wav');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(
                    isImage ? Icons.image : (isAudio ? Icons.mic : Icons.insert_drive_file),
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                    onPressed: () {
                      if (isAudio) {
                        _voiceService.playAudioFile(path);
                      } else {
                        OpenFilex.open(path);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                    onPressed: () => setState(() => _attachments.removeAt(i)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: const Color(0xFF0F0F0F),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(onPressed: _pickImage, icon: const Icon(Icons.image, color: Colors.white54)),
          IconButton(onPressed: _pickFile, icon: const Icon(Icons.attach_file, color: Colors.white54)),
          IconButton(
            onPressed: _toggleSpeech,
            icon: Icon(_isListening ? Icons.stop_circle : Icons.mic, color: _isListening ? Colors.red : Colors.white54),
          ),
        ],
      ),
    );
  }
}
