import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/village_model.dart';
import '../../services/village_service.dart';
import '../../widgets/village_selector_sheet.dart';
import '../saathi/saathi_main_shell.dart';

class SaathiRegistrationScreen extends StatefulWidget {
  final String uid;
  final String phone;

  const SaathiRegistrationScreen({
    super.key,
    required this.uid,
    required this.phone,
  });

  @override
  State<SaathiRegistrationScreen> createState() =>
      _SaathiRegistrationScreenState();
}

class _SaathiRegistrationScreenState extends State<SaathiRegistrationScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final _nameCtrl = TextEditingController();
  VillageModel? _selectedVillage;
  List<VillageModel> _villages = [];
  File? _profilePhoto;

  String? _vehicleType;
  final _vehicleNumCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController();

  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _loadVillages();
  }

  Future<void> _loadVillages() async {
    final v = await VillageService.getVillages();
    if (mounted) setState(() => _villages = v);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _profilePhoto = File(picked.path));
    }
  }

  void _nextPage() {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    setState(() => _currentPage++);
  }

  void _prevPage() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
    setState(() => _currentPage--);
  }

  bool get _page1Valid =>
      _nameCtrl.text.trim().isNotEmpty && _selectedVillage != null;

  bool get _page2Valid =>
      _vehicleType != null && _vehicleNumCtrl.text.trim().isNotEmpty;

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);
    try {
      final uid = widget.uid;
      final phone = widget.phone;

      String photoUrl = '';
      if (_profilePhoto != null) {
        final ref = FirebaseStorage.instance.ref('profiles/$uid.jpg');
        await ref.putFile(_profilePhoto!);
        photoUrl = await ref.getDownloadURL();
      }

      final batch = FirebaseFirestore.instance.batch();

      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'uid': uid,
          'name': _nameCtrl.text.trim(),
          'displayName': _nameCtrl.text.trim(),
          'phone': phone,
          'role': 'saathi',
          'village': _selectedVillage!.name,
          'profilePhoto': photoUrl,
          'fcmToken': '',
          'isBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        FirebaseFirestore.instance.collection('saathis').doc(uid),
        {
          'uid': uid,
          'name': _nameCtrl.text.trim(),
          'phone': phone,
          'village': _selectedVillage!.name,
          'vehicleType': _vehicleType,
          'vehicleNumber': _vehicleNumCtrl.text.trim().toUpperCase(),
          'vehicleColor': _vehicleColorCtrl.text.trim(),
          'profilePhoto': photoUrl,
          'isAvailable': false,
          'isOnline': false,
          'isBlocked': false,
          'isVerified': false,
          'rating': 5.0,
          'totalRides': 0,
          'fcmToken': '',
          'position': {
            'geohash': '',
            'geopoint': const GeoPoint(0, 0),
          },
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SaathiMainShell()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vehicleNumCtrl.dispose();
    _vehicleColorCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
            child: Column(children: [
              Row(children: [
                if (_currentPage > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _prevPage,
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / 3,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFE65100)),
                      minHeight: 6,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(
                  '${_currentPage + 1} / 3',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ]),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _page1PersonalInfo(),
                _page2VehicleInfo(),
                _page3Confirmation(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _page1PersonalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'સ્વાગત છે! 🛵',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100)),
          ),
          const Text(
            'તમારી માહિતી ભરો / Fill your details',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFE65100), width: 2),
                  ),
                  child: _profilePhoto != null
                      ? ClipOval(
                          child:
                              Image.file(_profilePhoto!, fit: BoxFit.cover))
                      : const Icon(Icons.person_add_outlined,
                          size: 40, color: Color(0xFFE65100)),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE65100),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
                  ),
                ),
              ]),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _profilePhoto = null),
              child: const Text('Skip for now',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'પૂરું નામ / Full Name *',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tanvir Patel',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFFE65100), width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ગામ / Home Village *',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              if (_villages.isEmpty) await _loadVillages();
              if (!mounted) return;
              final v = await VillageSelectorSheet.show(context,
                  villages: _villages);
              if (v != null) setState(() => _selectedVillage = v);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedVillage != null
                      ? const Color(0xFFE65100)
                      : Colors.grey.shade300,
                  width: _selectedVillage != null ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Icon(Icons.location_on,
                    color: _selectedVillage != null
                        ? const Color(0xFFE65100)
                        : Colors.grey,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedVillage != null
                        ? '${_selectedVillage!.nameGu} · ${_selectedVillage!.name}'
                        : 'ગામ પસંદ કરો / Select village',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedVillage != null
                          ? const Color(0xFF212121)
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ]),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _page1Valid ? const Color(0xFFE65100) : Colors.grey.shade300,
                elevation: _page1Valid ? 4 : 0,
                shadowColor: const Color(0xFFE65100).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _page1Valid ? _nextPage : null,
              child: const Text(
                'આગળ / Next →',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page2VehicleInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'વાહન માહિતી 🚗',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100)),
          ),
          const Text(
            'Vehicle Information',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          const Text(
            'વાહન પ્રકાર / Vehicle Type *',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _vehicleTypeCard('bike', '🛵', 'Bike', 'બાઇક'),
            const SizedBox(width: 10),
            _vehicleTypeCard('auto', '🛺', 'Auto', 'ઑટો'),
            const SizedBox(width: 10),
            _vehicleTypeCard('cycle', '🚲', 'Cycle', 'સાઇકલ'),
          ]),
          const SizedBox(height: 20),
          const Text(
            'વાહન નંબર / Vehicle Number *',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _vehicleNumCtrl,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'GJ 05 AB 1234',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFFE65100), width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'વાહન રંગ / Vehicle Color (optional)',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _vehicleColorCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Red, Black, Blue',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFFE65100), width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _page2Valid ? const Color(0xFFE65100) : Colors.grey.shade300,
                elevation: _page2Valid ? 4 : 0,
                shadowColor: const Color(0xFFE65100).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _page2Valid ? _nextPage : null,
              child: const Text(
                'આગળ / Next →',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page3Confirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'બધું સાચું છે? ✅',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100)),
          ),
          const Text(
            'Confirm your details',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(children: [
              if (_profilePhoto != null)
                CircleAvatar(
                    radius: 40,
                    backgroundImage: FileImage(_profilePhoto!))
              else
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFE65100),
                  child: Text(
                    _nameCtrl.text.isNotEmpty
                        ? _nameCtrl.text[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              _summaryRow('નામ', _nameCtrl.text),
              _summaryRow('ગામ', _selectedVillage?.name ?? ''),
              _summaryRow('વાહન', _vehicleType ?? ''),
              _summaryRow('નંબર', _vehicleNumCtrl.text),
              if (_vehicleColorCtrl.text.isNotEmpty)
                _summaryRow('રંગ', _vehicleColorCtrl.text),
            ]),
          ),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: _acceptedTerms,
              activeColor: const Color(0xFFE65100),
              onChanged: (v) =>
                  setState(() => _acceptedTerms = v ?? false),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'હું GaamRide સેવાની શરતો સ્વીકારું છું અને સુરક્ષિત ડ્રાઇવિંગ કરવા સહમત છું.\n'
                  'I agree to GaamRide terms and safe driving.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _acceptedTerms
                    ? const Color(0xFFE65100)
                    : Colors.grey.shade300,
                elevation: _acceptedTerms ? 4 : 0,
                shadowColor: const Color(0xFFE65100).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed:
                  _acceptedTerms && !_isLoading ? _submitRegistration : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text(
                      'સાથી બનો / Become Saathi 🛵',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleTypeCard(
      String type, String emoji, String en, String gu) {
    final selected = _vehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFBE9E7)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE65100)
                  : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(gu,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? const Color(0xFFE65100)
                        : Colors.grey)),
            Text(en,
                style:
                    const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text('$label:',
            style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
