import 'dart:async';
import 'package:flutter/material.dart';

class TimerService extends ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  int _seconds = 0;
  Timer? _timer;
  bool _isRunning = false;

  int get seconds => _seconds;
  bool get isRunning => _isRunning;

  void toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _seconds++;
        notifyListeners();
      });
    }
    _isRunning = !_isRunning;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _seconds = 0;
    _isRunning = false;
    notifyListeners();
  }

  String formatTime(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
