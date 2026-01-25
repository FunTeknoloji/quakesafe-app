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
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Acil Durum Rehberi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            if (_permissionDenied)
              const Center(child: Text('Rehber izni verilmedi', style: TextStyle(color: Colors.white)))
            else if (_contacts == null)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _contacts!.length,
                  itemBuilder: (context, i) {
                    final contact = _contacts![i];
                    return ListTile(
                      title: Text(contact.displayName, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(contact.phones.isNotEmpty ? contact.phones.first.number : '', style: const TextStyle(color: Colors.white70)),
                      leading: CircleAvatar(backgroundColor: Colors.redAccent, child: Text(contact.displayName[0], style: const TextStyle(color: Colors.white))),
                      onTap: () async {
                        if (contact.phones.isNotEmpty) {
                          final Uri url = Uri.parse('tel:${contact.phones.first.number}');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await FlutterContacts.openExternalInsert();
          _fetchContacts();
        },
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
