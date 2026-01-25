import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

class LightModeScreen extends StatefulWidget {
  final bool isPolice;
  const LightModeScreen({super.key, this.isPolice = false});

  @override
  State<LightModeScreen> createState() => _LightModeScreenState();
}

class _LightModeScreenState extends State<LightModeScreen> {
  Color _currentColor = Colors.white;
  Timer? _timer;
  bool _isBlue = false;
  double _originalBrightness = 0.5;

  @override
  void initState() {
    super.initState();
    _initBrightness();
    if (widget.isPolice) {
      _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        setState(() {
          _isBlue = !_isBlue;
          _currentColor = _isBlue ? Colors.blue : Colors.red;
        });
      });
    }
  }

  Future<void> _initBrightness() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (e) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    ScreenBrightness().setScreenBrightness(_originalBrightness);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentColor,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: const Center(
            child: Text(
              'KAPATMAK İÇİN DOKUN',
              style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
        ),
      ),
    );
  }
}
