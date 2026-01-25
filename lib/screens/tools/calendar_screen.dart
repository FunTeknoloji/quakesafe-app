import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/calendar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<CalendarEvent> _events = [];
  final TextEditingController _eventController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (_selectedDay == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final events = await CalendarService.getEventsForDay(dateStr);
    setState(() {
      _events = events;
    });
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('GÜN PROGRAMI EKLE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _eventController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Etkinlik veya görev başlığı...',
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              if (_eventController.text.isNotEmpty) {
                final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
                await CalendarService.insertEvent(CalendarEvent(title: _eventController.text, date: dateStr));
                _eventController.clear();
                Navigator.pop(context);
                _loadEvents();
              }
            },
            child: const Text('EKLE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('TAKVİM', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'tr_TR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _loadEvents();
            },
            calendarStyle: CalendarStyle(
              defaultTextStyle: const TextStyle(color: Colors.white70),
              weekendTextStyle: const TextStyle(color: Colors.redAccent),
              todayDecoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              outsideDaysVisible: false,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay == null ? '' : DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDay!),
                  style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _showAddEventDialog,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          Expanded(
            child: _events.isEmpty
                ? Center(child: Text('Bu gün için program yok', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 13)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _events.length,
                    itemBuilder: (context, i) => _buildEventItem(_events[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(CalendarEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Colors.redAccent, size: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              event.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
            onPressed: () async {
              await CalendarService.deleteEvent(event.id!);
              _loadEvents();
            },
          ),
        ],
      ),
    );
  }
}
