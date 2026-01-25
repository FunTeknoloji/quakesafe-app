import 'package:flutter/material.dart';
import '../../services/timer_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final TimerService _timerService = TimerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('ZAMANLAYICI'), backgroundColor: Colors.black),
      body: ListenableBuilder(
        listenable: _timerService,
        builder: (context, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _timerService.formatTime(_timerService.seconds),
              style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBtn(
                  icon: _timerService.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _timerService.isRunning ? Colors.orangeAccent : Colors.greenAccent,
                  onTap: _timerService.toggleTimer,
                ),
                const SizedBox(width: 40),
                _buildBtn(
                  icon: Icons.refresh_rounded,
                  color: Colors.redAccent,
                  onTap: _timerService.reset,
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}
