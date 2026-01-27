import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/profile_service.dart';
import 'recordings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sosMessageController = TextEditingController();
  String? _photoPath;
  String? _emergencyContactName;
  String? _emergencyContactNumber;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await ProfileService.getUsername();
    final photo = await ProfileService.getProfilePhoto();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (name != null) _nameController.text = name;
      _photoPath = photo;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _emergencyContactName = prefs.getString('emergency_contact_name');
      _emergencyContactNumber = prefs.getString('emergency_contact_number');
      _sosMessageController.text = prefs.getString('custom_sos_message') ?? 'ACİL DURUM! Yardıma ihtiyacım var. Konumum:';
    });
  }

  Future<void> _saveProfile({bool showInfo = true}) async {
    await ProfileService.setUsername(_nameController.text.trim());
    if (_photoPath != null) await ProfileService.setProfilePhoto(_photoPath!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('custom_sos_message', _sosMessageController.text);

    if (showInfo && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değişiklikler Kaydedildi'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _photoPath = image.path;
      });
      // Auto-save photo path
      await ProfileService.setProfilePhoto(image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profil', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                          child: _photoPath == null ? const Icon(Icons.person, size: 60) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: _pickImage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration.collapsed(
                        hintText: 'Adınız',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onChanged: (value) => _saveProfile(showInfo: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildProfileOption(
                context,
                icon: Icons.emergency,
                title: 'Acil Durum Kişisi',
                subtitle: _emergencyContactName ?? 'Seçilmedi',
                onTap: _pickEmergencyContact,
              ),
              _buildProfileOption(
                context,
                icon: Icons.message,
                title: 'Acil Durum Mesajı',
                onTap: () {
                  // Show dialog to edit SOS message
                },
              ),
              _buildProfileOption(
                context,
                icon: Icons.mic,
                title: 'Ses Kayıtları',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RecordingsScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1));
  }

  Widget _buildEmergencyContactTile() {
    return GestureDetector(
      onTap: _pickEmergencyContact,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emergency_share_rounded, color: Colors.redAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Acil Durum Kişisi', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(
                    _emergencyContactName ?? 'Kişi seçilmedi',
                    style: TextStyle(color: _emergencyContactName != null ? Colors.white : Colors.white24, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEmergencyContact() async {
    if (await FlutterContacts.requestPermission()) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null && contact.phones.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _emergencyContactName = contact.displayName;
          _emergencyContactNumber = contact.phones.first.number;
        });
        await prefs.setString('emergency_contact_name', contact.displayName);
        await prefs.setString('emergency_contact_number', contact.phones.first.number);
        _saveProfile();
      }
    }
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool autoSave = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        onChanged: (v) {
          if (autoSave) _saveProfile(showInfo: false);
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          contentPadding: const EdgeInsets.all(20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent, size: 20),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context,
      {required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.grey))
          : null,
      onTap: onTap,
    );
  }
}
