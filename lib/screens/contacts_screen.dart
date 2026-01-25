import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future _fetchContacts() async {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Text(
                'REHBER',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (_permissionDenied)
              _buildErrorState('Rehber erişim izni verilmedi.')
            else if (_contacts == null)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.redAccent)))
            else if (_contacts!.isEmpty)
              _buildErrorState('Rehberinizde kişi bulunamadı.')
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _contacts!.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final contact = _contacts![i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.redAccent, Colors.red.shade900],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              contact.displayName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ),
                        ),
                        title: Text(contact.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          contact.phones.isNotEmpty ? contact.phones.first.number : 'Numara yok',
                          style: const TextStyle(color: Colors.white38),
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.phone_rounded, color: Colors.greenAccent, size: 20),
                            onPressed: () async {
                              if (contact.phones.isNotEmpty) {
                                final Uri url = Uri.parse('tel:${contact.phones.first.number}');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await FlutterContacts.openExternalInsert();
          _fetchContacts();
        },
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('KİŞİ EKLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
