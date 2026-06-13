import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';

class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});

  factory EmergencyContact.fromMap(Map<String, dynamic> m) =>
      EmergencyContact(name: m['name'] ?? '', phone: m['phone'] ?? '');

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
}

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  static const _maxContacts = 3;

  final List<TextEditingController> _nameCtrl =
      List.generate(_maxContacts, (_) => TextEditingController());
  final List<TextEditingController> _phoneCtrl =
      List.generate(_maxContacts, (_) => TextEditingController());

  bool _loading = true;
  bool _saving = false;

  DocumentReference get _docRef {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('emergency_contacts');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _docRef.get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      final contacts = (data['contacts'] as List? ?? [])
          .map((e) => EmergencyContact.fromMap(e as Map<String, dynamic>))
          .toList();
      for (var i = 0; i < contacts.length && i < _maxContacts; i++) {
        _nameCtrl[i].text = contacts[i].name;
        _phoneCtrl[i].text = contacts[i].phone;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final contacts = <Map<String, dynamic>>[];
    for (var i = 0; i < _maxContacts; i++) {
      final name = _nameCtrl[i].text.trim();
      final phone = _phoneCtrl[i].text.trim();
      if (name.isNotEmpty && phone.isNotEmpty) {
        contacts.add(EmergencyContact(name: name, phone: phone).toMap());
      }
    }
    await _docRef.set({'contacts': contacts, 'updatedAt': FieldValue.serverTimestamp()});
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contacts saved'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  static Future<List<EmergencyContact>> getContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('emergency_contacts')
        .get();
    if (!snap.exists) return [];
    final data = snap.data() as Map<String, dynamic>;
    return (data['contacts'] as List? ?? [])
        .map((e) => EmergencyContact.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> callFirstContact() async {
    final contacts = await getContacts();
    if (contacts.isEmpty) return;
    final phone = contacts.first.phone;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _testCall(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    for (final c in [..._nameCtrl, ..._phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE08A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF856404), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These contacts will be called when you press the SOS button during a ride.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < _maxContacts; i++) ...[
                    _ContactSlot(
                      index: i + 1,
                      nameCtrl: _nameCtrl[i],
                      phoneCtrl: _phoneCtrl[i],
                      onTestCall: () => _testCall(_phoneCtrl[i].text.trim()),
                    ),
                    if (i < _maxContacts - 1) const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Contacts',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ContactSlot extends StatelessWidget {
  final int index;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onTestCall;

  const _ContactSlot({
    required this.index,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onTestCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: index == 1 ? AppColors.primaryGreen : AppColors.bgGreen,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: index == 1 ? Colors.white : AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                index == 1 ? 'Primary Contact' : 'Contact $index',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const Spacer(),
              if (phoneCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: onTestCall,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.call, size: 12, color: AppColors.primaryGreen),
                        SizedBox(width: 4),
                        Text('Test',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Ramesh bhai',
              prefixIcon: const Icon(Icons.person_outline, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '9876543210',
              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
