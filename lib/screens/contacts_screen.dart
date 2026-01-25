import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact>? _allContacts;
  List<Contact>? _filteredContacts;
  bool _permissionDenied = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

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
      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _allContacts?.where((contact) {
        return contact.displayName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
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
      padding: const EdgeInsets.all(20.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isSearching ? _buildSearchBar() : _buildNormalHeader(),
      ),
    );
  }

  Widget _buildNormalHeader() {
    return Row(
      key: const ValueKey('normal'),
      children: [
        const Text('REHBER', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _isSearching = true),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.search_rounded, color: Colors.redAccent, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(onPressed: _fetchContacts, icon: const Icon(Icons.refresh_rounded, color: Colors.white54)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      key: const ValueKey('search'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        onChanged: _filterContacts,
        decoration: InputDecoration(
          hintText: 'İsim arayın...',
          hintStyle: const TextStyle(color: Colors.white38),
          border: InputBorder.none,
          icon: const Icon(Icons.search_rounded, color: Colors.redAccent),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
                _filteredContacts = _allContacts;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) return const Center(child: Text('İzin Reddedildi', style: TextStyle(color: Colors.white54)));
    if (_filteredContacts == null) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    if (_filteredContacts!.isEmpty) return const Center(child: Text('Kişi Bulunamadı', style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredContacts!.length,
      itemBuilder: (context, i) {
        final c = _filteredContacts![i];
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
              backgroundImage: c.thumbnail != null ? MemoryImage(c.thumbnail!) : null,
              child: c.thumbnail == null ? Text(c.displayName.isNotEmpty ? c.displayName[0] : '?', style: const TextStyle(color: Colors.redAccent)) : null,
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
