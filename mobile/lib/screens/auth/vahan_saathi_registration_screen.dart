import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/village_model.dart';
import '../../services/village_service.dart';
import '../../widgets/village_selector_sheet.dart';
import '../haul_owner/vahan_saathi_pending_screen.dart';

class VahanSaathiRegistrationScreen extends StatefulWidget {
  final String uid;
  final String phone;

  const VahanSaathiRegistrationScreen({
    super.key,
    required this.uid,
    required this.phone,
  });

  @override
  State<VahanSaathiRegistrationScreen> createState() =>
      _VahanSaathiRegistrationScreenState();
}

class _VahanSaathiRegistrationScreenState
    extends State<VahanSaathiRegistrationScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  bool _isLoading = false;
  List<VillageModel> _villages = [];

  // Step 1 — Personal
  File? _profilePhoto;
  final _nameCtrl = TextEditingController();
  VillageModel? _village;

  // Step 2 — Vehicle type
  String? _vehicleType;

  // Step 3 — Vehicle details
  final _vehicleNumCtrl = TextEditingController();
  final _vehicleBrandCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  String? _capacity;

  // Step 4 — Documents
  File? _dlFront, _dlBack, _rcFile, _vehiclePhoto, _insuranceFile, _pucFile;

  // Step 5 — Bank / UPI (optional)
  final _upiCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  bool _acceptedTerms = false;

  static const _vehicleTypes = [
    {'key': 'chhota_hathi',       'emoji': '🚚', 'label': 'Chhota Hathi / Tata Ace'},
    {'key': 'tata_ace_gold_cng',  'emoji': '🚚', 'label': 'Tata Ace Gold CNG'},
    {'key': 'mahindra_jeeto',     'emoji': '🚚', 'label': 'Mahindra Jeeto'},
    {'key': 'ashok_leyland_dost', 'emoji': '🚚', 'label': 'Ashok Leyland Dost'},
    {'key': 'maruti_super_carry', 'emoji': '🚚', 'label': 'Maruti Super Carry'},
    {'key': 'bolero_pickup',      'emoji': '🛻', 'label': 'Bolero Pickup'},
    {'key': 'tata_yodha',         'emoji': '🛻', 'label': 'Tata Yodha Pickup'},
    {'key': 'eicher_truck',       'emoji': '🚛', 'label': 'Eicher Truck'},
    {'key': 'tractor',            'emoji': '🚜', 'label': 'Tractor'},
    {'key': 'cargo_tempo',        'emoji': '📦', 'label': 'Cargo Tempo'},
    {'key': 'cng_cargo',          'emoji': '⛽', 'label': 'CNG Cargo Vehicle'},
    {'key': 'other',              'emoji': '🚛', 'label': 'Other Vehicle'},
  ];

  static const _capacities = ['500 kg', '1 Ton', '2 Ton', '3 Ton', '5 Ton', '10+ Ton'];

  static const _brown = Color(0xFF5D4037);
  static const _lightBrown = Color(0xFFEFEBE9);

  @override
  void initState() {
    super.initState();
    _loadVillages();
  }

  Future<void> _loadVillages() async {
    final v = await VillageService.getVillages();
    if (mounted) setState(() => _villages = v);
  }

  void _go(int p) {
    _pageCtrl.animateToPage(p,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _page = p);
  }

  bool get _step1Valid =>
      _nameCtrl.text.trim().isNotEmpty && _village != null;

  bool get _step2Valid => _vehicleType != null;

  bool get _step3Valid =>
      _vehicleNumCtrl.text.trim().isNotEmpty && _capacity != null;

  bool get _step4Valid =>
      _dlFront != null && _dlBack != null &&
      _rcFile != null && _vehiclePhoto != null;

  Future<void> _pickPhoto(ImageSource src, Function(File) onPick) async {
    final p = await ImagePicker()
        .pickImage(source: src, maxWidth: 1024, imageQuality: 80);
    if (p != null && mounted) onPick(File(p.path));
  }

  Future<String> _upload(File file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please accept terms and conditions.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uid = widget.uid;
      final base = 'vahan_saathi/$uid';

      // Upload all files in parallel
      final futures = <Future<String>>[];
      futures.add(_profilePhoto != null
          ? _upload(_profilePhoto!, '$base/profile.jpg')
          : Future.value(''));
      futures.add(_upload(_dlFront!, '$base/dl_front.jpg'));
      futures.add(_upload(_dlBack!, '$base/dl_back.jpg'));
      futures.add(_upload(_rcFile!, '$base/rc.jpg'));
      futures.add(_upload(_vehiclePhoto!, '$base/vehicle.jpg'));
      futures.add(_insuranceFile != null
          ? _upload(_insuranceFile!, '$base/insurance.jpg')
          : Future.value(''));
      futures.add(_pucFile != null
          ? _upload(_pucFile!, '$base/puc.jpg')
          : Future.value(''));

      final urls = await Future.wait(futures);
      final profileUrl = urls[0];
      final dlFrontUrl = urls[1];
      final dlBackUrl  = urls[2];
      final rcUrl      = urls[3];
      final vehicleUrl = urls[4];
      final insurUrl   = urls[5];
      final pucUrl     = urls[6];

      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'uid': uid,
          'name': _nameCtrl.text.trim(),
          'displayName': _nameCtrl.text.trim(),
          'phone': widget.phone,
          'role': 'haul_owner',
          'village': _village!.name,
          'profilePhoto': profileUrl,
          'fcmToken': '',
          'isBlocked': false,
          'createdAt': now,
          'updatedAt': now,
        },
      );

      batch.set(
        FirebaseFirestore.instance.collection('haul_vehicles').doc(uid),
        {
          'uid': uid,
          'ownerName': _nameCtrl.text.trim(),
          'phone': widget.phone,
          'village': _village!.name,
          'vehicleType': _vehicleType,
          'vehicleBrand': _vehicleBrandCtrl.text.trim(),
          'vehicleModel': _vehicleModelCtrl.text.trim(),
          'capacity': _capacity ?? '',
          'vehicleNumber': _vehicleNumCtrl.text.trim().toUpperCase(),
          'ratePerHour': 0,
          'isAvailable': false,
          'isOnline': false,
          'isBlocked': false,
          'isVerified': false,
          'totalBookings': 0,
          'rating': 5.0,
          'fcmToken': '',
          'profilePhotoUrl': profileUrl,
          'dlFrontUrl': dlFrontUrl,
          'dlBackUrl': dlBackUrl,
          'rcUrl': rcUrl,
          'vehiclePhotoUrl': vehicleUrl,
          'insuranceUrl': insurUrl,
          'pucUrl': pucUrl,
          'upiId': _upiCtrl.text.trim(),
          'bankAccount': _bankCtrl.text.trim(),
          'ifsc': _ifscCtrl.text.trim().toUpperCase(),
          'status': 'pending',
          'rejectionReason': '',
          'createdAt': now,
        },
      );

      await batch.commit();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => VahanSaathiPendingScreen(uid: uid)),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: $e'),
                backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _vehicleNumCtrl.dispose();
    _vehicleBrandCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _upiCtrl.dispose();
    _bankCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final steps = ['Personal', 'Vehicle Type', 'Details', 'Documents', 'Review'];
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(children: [
        // Header
        Container(
          color: _brown,
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (_page > 0)
                  GestureDetector(
                    onTap: () => _go(_page - 1),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vahan Saathi Registration',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('Step ${_page + 1} of ${steps.length}: ${steps[_page]}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                )),
              ]),
              const SizedBox(height: 12),
              // Progress bar
              Row(children: List.generate(steps.length, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < steps.length - 1 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: i <= _page
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
                ),
              ))),
            ],
          ),
        ),

        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(),
              _buildStep2(),
              _buildStep3(),
              _buildStep4(),
              _buildStep5(),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Step 1: Personal ──────────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('👤 Personal Details / અંગત માહિતી'),
        const SizedBox(height: 20),

        // Profile photo
        Center(child: GestureDetector(
          onTap: () => _pickPhoto(ImageSource.gallery,
              (f) => setState(() => _profilePhoto = f)),
          child: Stack(children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: _lightBrown,
              backgroundImage: _profilePhoto != null
                  ? FileImage(_profilePhoto!) : null,
              child: _profilePhoto == null
                  ? const Icon(Icons.person, size: 52, color: Color(0xFF8D6E63))
                  : null,
            ),
            Positioned(bottom: 0, right: 0,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: _brown, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt,
                    color: Colors.white, size: 15),
              )),
          ]),
        )),
        const SizedBox(height: 6),
        const Center(child: Text('Profile Photo (Optional)',
            style: TextStyle(color: Colors.grey, fontSize: 12))),

        const SizedBox(height: 24),

        _Label('Full Name / પૂરું નામ *'),
        const SizedBox(height: 6),
        _field(_nameCtrl, 'e.g. Ramesh Patel',
            inputType: TextInputType.name),

        const SizedBox(height: 20),

        _Label('Village / ગામ *'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final v = await VillageSelectorSheet.show(context,
                villages: _villages);
            if (v != null) setState(() => _village = v);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _village != null
                      ? _brown : Colors.grey.shade300)),
            child: Row(children: [
              const Icon(Icons.location_on_outlined,
                  color: Color(0xFF8D6E63), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _village != null
                    ? '${_village!.nameGu} · ${_village!.name}'
                    : 'ગામ પસંદ કરો / Select village',
                style: TextStyle(
                    color: _village != null
                        ? Colors.black87 : Colors.grey,
                    fontSize: 15),
              )),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ]),
          ),
        ),

        const SizedBox(height: 32),
        _nextBtn('આગળ વધો / Next', _step1Valid, () => _go(1)),
      ]),
    );
  }

  // ── Step 2: Vehicle Type ───────────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('🚚 વાહન પ્રકાર પસંદ કરો'),
        const SizedBox(height: 4),
        const Text('Select your vehicle type',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 20),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: _vehicleTypes.map((v) {
            final selected = _vehicleType == v['key'];
            return GestureDetector(
              onTap: () => setState(() => _vehicleType = v['key']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected ? _brown : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: selected ? _brown : Colors.grey.shade200,
                      width: selected ? 2 : 1),
                  boxShadow: selected ? [
                    BoxShadow(color: _brown.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 3))
                  ] : [],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(v['emoji']!,
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 6),
                      Text(v['label']!,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : Colors.black87),
                        textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _outlineBtn('Back', () => _go(0))),
          const SizedBox(width: 12),
          Expanded(child: _nextBtn('Next', _step2Valid, () => _go(2))),
        ]),
      ]),
    );
  }

  // ── Step 3: Vehicle Details ────────────────────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('📋 Vehicle Details / વાહન માહિતી'),
        const SizedBox(height: 20),

        _Label('Vehicle Number / વાહન નંબર *'),
        const SizedBox(height: 6),
        _field(_vehicleNumCtrl, 'GJ-18-XXXX',
            caps: TextCapitalization.characters,
            inputFormatters: [UpperCaseFormatter()]),

        const SizedBox(height: 16),

        _Label('Brand / બ્રાન્ડ (Optional)'),
        const SizedBox(height: 6),
        _field(_vehicleBrandCtrl, 'e.g. Tata, Mahindra'),

        const SizedBox(height: 16),

        _Label('Model (Optional)'),
        const SizedBox(height: 6),
        _field(_vehicleModelCtrl, 'e.g. Ace, Jeeto'),

        const SizedBox(height: 16),

        _Label('Load Capacity / ભાર ક્ષમતા *'),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10,
          children: _capacities.map((c) {
            final selected = _capacity == c;
            return GestureDetector(
              onTap: () => setState(() => _capacity = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _brown : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? _brown : Colors.grey.shade300)),
                child: Text(c,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _outlineBtn('Back', () => _go(1))),
          const SizedBox(width: 12),
          Expanded(child: _nextBtn('Next', _step3Valid, () => _go(3))),
        ]),
      ]),
    );
  }

  // ── Step 4: Documents ─────────────────────────────────────────────────────

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('📄 Upload Documents'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200)),
          child: const Row(children: [
            Icon(Icons.lock_outline, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'તમારા દસ્તાવેજો સુરક્ષિત રાખવામાં આવશે',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        const Text('Required Documents',
            style: TextStyle(fontWeight: FontWeight.bold,
                color: Colors.black87, fontSize: 14)),
        const SizedBox(height: 14),

        _DocUploader(
          label: 'Driving Licence — Front *',
          sublabel: 'DL આગળ',
          file: _dlFront,
          onPick: () => _pickPhoto(
              ImageSource.gallery, (f) => setState(() => _dlFront = f)),
        ),
        const SizedBox(height: 12),
        _DocUploader(
          label: 'Driving Licence — Back *',
          sublabel: 'DL પાછળ',
          file: _dlBack,
          onPick: () => _pickPhoto(
              ImageSource.gallery, (f) => setState(() => _dlBack = f)),
        ),
        const SizedBox(height: 12),
        _DocUploader(
          label: 'RC Book *',
          sublabel: 'Registration Certificate',
          file: _rcFile,
          onPick: () => _pickPhoto(
              ImageSource.gallery, (f) => setState(() => _rcFile = f)),
        ),
        const SizedBox(height: 12),
        _DocUploader(
          label: 'Vehicle Photo *',
          sublabel: 'Clear photo of your vehicle',
          file: _vehiclePhoto,
          onPick: () => _pickPhoto(
              ImageSource.gallery, (f) => setState(() => _vehiclePhoto = f)),
        ),

        const SizedBox(height: 24),
        const Text('Optional Documents',
            style: TextStyle(fontWeight: FontWeight.bold,
                color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 14),

        _DocUploader(
          label: 'Insurance Copy',
          sublabel: 'Optional',
          file: _insuranceFile,
          required: false,
          onPick: () => _pickPhoto(
              ImageSource.gallery, (f) => setState(() => _insuranceFile = f)),
        ),
        const SizedBox(height: 12),
        _DocUploader(
          label: 'PUC Certificate',
          sublabel: 'Optional',
          file: _pucFile,
          required: false,
          onPick: () => _pickPhoto(
              ImageSource.gallery, (f) => setState(() => _pucFile = f)),
        ),

        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _outlineBtn('Back', () => _go(2))),
          const SizedBox(width: 12),
          Expanded(child: _nextBtn('Next', _step4Valid, () => _go(4))),
        ]),
      ]),
    );
  }

  // ── Step 5: Bank + Review ─────────────────────────────────────────────────

  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('💳 Bank / UPI Details (Optional)'),
        const SizedBox(height: 6),
        const Text('For future payouts. You can skip this.',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),

        _Label('UPI ID (Optional)'),
        const SizedBox(height: 6),
        _field(_upiCtrl, 'yourname@upi',
            inputType: TextInputType.emailAddress),

        const SizedBox(height: 16),

        const Row(children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: 16),

        _Label('Bank Account Number (Optional)'),
        const SizedBox(height: 6),
        _field(_bankCtrl, 'Account number',
            inputType: TextInputType.number),

        const SizedBox(height: 16),

        _Label('IFSC Code (Optional)'),
        const SizedBox(height: 6),
        _field(_ifscCtrl, 'e.g. SBIN0001234',
            caps: TextCapitalization.characters),

        const SizedBox(height: 28),

        // Summary review card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Review Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            _ReviewRow('👤', 'Name', _nameCtrl.text.trim()),
            _ReviewRow('📍', 'Village', _village?.name ?? ''),
            _ReviewRow('🚚', 'Vehicle Type',
                _vehicleTypes.firstWhere(
                    (v) => v['key'] == _vehicleType,
                    orElse: () => {'label': ''})['label']!),
            _ReviewRow('🔢', 'Vehicle No',
                _vehicleNumCtrl.text.trim().toUpperCase()),
            _ReviewRow('📦', 'Capacity', _capacity ?? ''),
            _ReviewRow('📄', 'DL', _dlFront != null ? '✅ Uploaded' : '❌'),
            _ReviewRow('📄', 'RC', _rcFile != null ? '✅ Uploaded' : '❌'),
            _ReviewRow('📷', 'Vehicle Photo',
                _vehiclePhoto != null ? '✅ Uploaded' : '❌'),
          ]),
        ),

        const SizedBox(height: 20),

        // Terms
        GestureDetector(
          onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: _acceptedTerms,
              onChanged: (v) =>
                  setState(() => _acceptedTerms = v ?? false),
              activeColor: _brown,
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'I agree to GaamRide Terms of Service and confirm all '
                  'information is accurate.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _outlineBtn('Back', () => _go(3))),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brown,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: _brown.withOpacity(0.4),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Submit for Verification',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 32),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _nextBtn(String label, bool enabled, VoidCallback onTap) =>
      SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? _brown : Colors.grey.shade300,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: enabled ? 4 : 0,
            shadowColor: _brown.withOpacity(0.4),
          ),
          onPressed: enabled ? onTap : null,
          child: Text(label,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );

  Widget _outlineBtn(String label, VoidCallback onTap) => SizedBox(
    height: 52,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _brown,
        side: BorderSide(color: _brown),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      child: Text(label),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType inputType = TextInputType.text,
    TextCapitalization caps = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: inputType,
        textCapitalization: caps,
        inputFormatters: inputFormatters,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF5D4037), width: 2)),
        ),
      );

  Widget _Label(String t) =>
      Text(t, style: const TextStyle(fontWeight: FontWeight.w600,
          fontSize: 13, color: Colors.black87));

  Widget _ReviewRow(String emoji, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Text(value.isNotEmpty ? value : '—',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}

// ── Reusable Widgets ───────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
          color: Color(0xFF3E2723)));
}

class _DocUploader extends StatelessWidget {
  final String label;
  final String sublabel;
  final File? file;
  final VoidCallback onPick;
  final bool required;

  const _DocUploader({
    required this.label,
    required this.sublabel,
    required this.file,
    required this.onPick,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = file != null;
    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: uploaded ? const Color(0xFFF1EBE9) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: uploaded ? const Color(0xFF5D4037)
                  : required ? Colors.grey.shade300 : Colors.grey.shade200,
              width: uploaded ? 2 : 1)),
        child: Row(children: [
          if (uploaded)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(file!, width: 54, height: 54,
                  fit: BoxFit.cover))
          else
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.upload_file_outlined,
                  color: Colors.grey, size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600,
                      fontSize: 13))),
              if (required && !uploaded)
                const Text('*', style: TextStyle(color: Colors.red,
                    fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 2),
            Text(sublabel, style: const TextStyle(
                color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              uploaded ? '✅ Uploaded — tap to change'
                  : 'Tap to upload photo',
              style: TextStyle(
                  fontSize: 11,
                  color: uploaded ? const Color(0xFF5D4037) : Colors.blue),
            ),
          ])),
        ]),
      ),
    );
  }
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue newVal) =>
      newVal.copyWith(text: newVal.text.toUpperCase());
}
