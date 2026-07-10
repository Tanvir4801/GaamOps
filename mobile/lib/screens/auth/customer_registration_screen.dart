import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/village_model.dart';
import '../../services/village_service.dart';
import '../../services/ride_service.dart';
import '../../widgets/village_selector_sheet.dart';
import '../customer/customer_main_shell.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  final String uid;
  final String phone;

  const CustomerRegistrationScreen({
    super.key,
    required this.uid,
    required this.phone,
  });

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  VillageModel? _selectedVillage;
  List<VillageModel> _villages = [];
  File? _profilePhoto;
  bool _isLoading = false;
  String? _error;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _loadVillages();
    _animCtrl.forward();
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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'નામ ભરો / Please enter your name');
      return;
    }
    if (_selectedVillage == null) {
      setState(() => _error = 'ગામ પસંદ કરો / Please select your village');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String photoUrl = '';
      if (_profilePhoto != null) {
        final ref =
            FirebaseStorage.instance.ref('profiles/${widget.uid}.jpg');
        await ref.putFile(_profilePhoto!);
        photoUrl = await ref.getDownloadURL();
      }

      // Generate a unique 4-digit ride code for this customer (once at signup)
      final rideCode = await generateUniqueRideCode();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set({
        'uid': widget.uid,
        'name': name,
        'displayName': name,
        'phone': widget.phone,
        'role': 'customer',
        'village': _selectedVillage!.name,
        'profilePhoto': photoUrl,
        'fcmToken': '',
        'isBlocked': false,
        'rideCode': rideCode,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerMainShell()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Registration failed. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BackButton(
                    color: Colors.white,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'સ્વાગત છે! 👤',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Customer Profile બનાવો / Create your profile',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF2E7D32), width: 2),
                            ),
                            child: _profilePhoto != null
                                ? ClipOval(
                                    child: Image.file(_profilePhoto!,
                                        fit: BoxFit.cover))
                                : const Icon(Icons.person_add_outlined,
                                    size: 40, color: Color(0xFF2E7D32)),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
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
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'પૂરું નામ / Full Name *',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
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
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF2E7D32), width: 2),
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
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        if (_villages.isEmpty) {
                          await _loadVillages();
                        }
                        if (!mounted) return;
                        final v = await VillageSelectorSheet.show(
                          context,
                          villages: _villages,
                        );
                        if (v != null) setState(() => _selectedVillage = v);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedVillage != null
                                ? const Color(0xFF2E7D32)
                                : Colors.grey.shade300,
                            width: _selectedVillage != null ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.location_on,
                              color: _selectedVillage != null
                                  ? const Color(0xFF2E7D32)
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
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _nameCtrl.text.isNotEmpty &&
                                  _selectedVillage != null
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade300,
                          elevation:
                              _nameCtrl.text.isNotEmpty && _selectedVillage != null
                                  ? 4
                                  : 0,
                          shadowColor:
                              const Color(0xFF2E7D32).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed:
                            _isLoading || _nameCtrl.text.isEmpty || _selectedVillage == null
                                ? null
                                : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text(
                                'GaamRide શરૂ કરો / Start Riding',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
