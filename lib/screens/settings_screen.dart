import 'package:flutter/material.dart';
import 'package:quakesafe_app/main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Language'),
            subtitle: const Text('English'),
            onTap: () {
              // TODO: Implement language selection
            },
          ),
        ],
      ),
    );
  }
}
