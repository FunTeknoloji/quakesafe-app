import 'package:flutter/material.dart';
import '../../services/notes_service.dart';
import 'note_detail_screen.dart';

class NotepadScreen extends StatefulWidget {
  const NotepadScreen({super.key});

  @override
  State<NotepadScreen> createState() => _NotepadScreenState();
}

class _NotepadScreenState extends State<NotepadScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshNotes();
  }

  Future<void> _refreshNotes() async {
    final notes = await NotesService.getNotes();
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('NOTLARIM', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _notes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _notes.length,
                  itemBuilder: (context, i) => _buildNoteCard(_notes[i]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NoteDetailScreen()),
        ).then((_) => _refreshNotes()),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text('Henüz not eklenmemiş', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        title: Text(
          note.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12, color: Colors.white24),
                const SizedBox(width: 6),
                Text(note.date, style: const TextStyle(color: Colors.white24, fontSize: 12)),
                const Spacer(),
                if (note.attachments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, size: 12, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text('${note.attachments.length}', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note)),
        ).then((_) => _refreshNotes()),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () async {
            await NotesService.deleteNote(note.id!);
            _refreshNotes();
          },
        ),
      ),
    );
  }
}
