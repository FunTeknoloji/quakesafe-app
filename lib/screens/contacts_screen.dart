import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact>? _contacts;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      setState(() => _permissionDenied = true);
    } else {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      setState(() => _contacts = contacts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          const Text('REHBER', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Spacer(),
          IconButton(onPressed: _fetchContacts, icon: const Icon(Icons.refresh_rounded, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) return const Center(child: Text('İzin Reddedildi', style: TextStyle(color: Colors.white54)));
    if (_contacts == null) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    if (_contacts!.isEmpty) return const Center(child: Text('Kişi Bulunamadı', style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _contacts!.length,
      itemBuilder: (context, i) {
        final c = _contacts![i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.03)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              child: Text(c.displayName.isNotEmpty ? c.displayName[0] : '?', style: const TextStyle(color: Colors.redAccent)),
            ),
            title: Text(c.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(c.phones.isNotEmpty ? c.phones.first.number : 'No Number', style: const TextStyle(color: Colors.white38)),
            trailing: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.call_outlined, color: Colors.greenAccent, size: 20),
            ),
          ),
        );
      },
    );
  }
}
