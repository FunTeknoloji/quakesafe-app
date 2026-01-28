import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact>? _allContacts;
  List<Contact>? _filteredContacts;
  Contact? _emergencyContact;
  bool _permissionDenied = false;
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _sendSOS(Contact contact) async {
    if (contact.phones.isEmpty) return;
    final number = contact.phones.first.number;

    final prefs = await SharedPreferences.getInstance();
    final customMsg = prefs.getString('custom_sos_message') ?? 'ACİL DURUM! Yardıma ihtiyacım var. Konumum:';

    try {
      Position pos = await Geolocator.getCurrentPosition();
      String url = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
      final Uri uri = Uri.parse('sms:$number?body=$customMsg $url');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS hazırlanamadı')));
    }
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
      return;
    }

    final allContactsList = await FlutterContacts.getContacts(withProperties: true, withPhoto: true);
    final prefs = await SharedPreferences.getInstance();
    final emergencyNumber = prefs.getString('emergency_contact_number');

    Contact? emergencyContact;

    if (emergencyNumber != null && emergencyNumber.isNotEmpty) {
      final emergencyContactIndex = allContactsList.indexWhere(
        (c) => c.phones.any((p) => p.number.replaceAll(RegExp(r'[^0-9+]'), '') == emergencyNumber.replaceAll(RegExp(r'[^0-9+]'), ''))
      );

      if (emergencyContactIndex != -1) {
        emergencyContact = allContactsList.removeAt(emergencyContactIndex);
      }
    }

    setState(() {
      _emergencyContact = emergencyContact;
      _allContacts = allContactsList;
      _filteredContacts = allContactsList;
      _isLoading = false;
    });
  }


  void _filterContacts(String query) {
    if (_allContacts == null) return;
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts!.where((contact) {
          return contact.displayName.toLowerCase().contains(lowerCaseQuery);
        }).toList();
      }
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
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    if (_permissionDenied) return const Center(child: Text('Rehber izni reddedildi.', style: TextStyle(color: Colors.white54)));
    if (_allContacts == null) return const Center(child: Text('Rehber yüklenemedi.', style: TextStyle(color: Colors.white54)));

    return CustomScrollView(
      slivers: [
        if (_emergencyContact != null && !_isSearching) ...[
          _buildSectionHeader('ACİL DURUM KİŞİSİ'),
          SliverToBoxAdapter(child: _buildEmergencyContactCard(_emergencyContact!)),
        ],
        if (!_isSearching) _buildSectionHeader('TÜM KİŞİLER'),
        if (_filteredContacts!.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                _isSearching ? 'Arama sonucu bulunamadı.' : 'Rehberinizde kişi bulunamadı.',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildContactItem(_filteredContacts![index]),
                childCount: _filteredContacts!.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactCard(Contact contact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 4,
        shadowColor: Colors.redAccent.withOpacity(0.3),
        color: const Color(0xFF2D1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: _buildContactItem(contact, isEmergency: true),
      ),
    );
  }

  Widget _buildContactItem(Contact contact, {bool isEmergency = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: isEmergency ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.1),
        backgroundImage: contact.photo != null ? MemoryImage(contact.photo!) : null,
        child: contact.photo == null
            ? Text(
                contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isEmergency ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )
            : null,
      ),
      title: Text(
        contact.displayName,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        contact.phones.isNotEmpty ? contact.phones.first.number : 'Numara yok',
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _sendSOS(contact),
            tooltip: 'SOS Mesajı Gönder',
            icon: Icon(Icons.emergency_share_outlined, color: isEmergency ? Colors.yellowAccent : Colors.redAccent, size: 22),
          ),
          IconButton(
            onPressed: () async {
              if (contact.phones.isNotEmpty) {
                final Uri url = Uri.parse('tel:${contact.phones.first.number}');
                if (await canLaunchUrl(url)) await launchUrl(url);
              }
            },
            tooltip: 'Ara',
            icon: const Icon(Icons.call_outlined, color: Colors.greenAccent, size: 22),
          ),
        ],
      ),
    );
  }
}
