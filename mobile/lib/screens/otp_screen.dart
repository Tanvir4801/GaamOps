import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'auth/customer_registration_screen.dart';
import 'auth/saathi_registration_screen.dart';
import 'saathi/saathi_main_shell.dart';
import 'customer/customer_main_shell.dart';
import 'haul_owner/haul_owner_shell.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String role;
  final String verificationId;
  final UserCredential? userCredential;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.role,
    required this.verificationId,
    this.userCredential,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  bool get _isSaathi => widget.role == 'saathi';
  Color get _color => _isSaathi ? AppColors.primaryOrange : AppColors.primaryGreen;

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    if (widget.userCredential != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handlePostLogin(widget.userCredential!.user!.uid, widget.role));
    }
  }

  void _goRemoveAll(Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }

  Future<void> _verify() async {
    if (_otp.length != 6) {
      setState(() => _error = 'Please enter 6-digit OTP');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otp,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      await _handlePostLogin(userCred.user!.uid, widget.role);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message ?? 'Invalid OTP. Try again.';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  // Migrate admin-created temp saathi doc (docId = phone number) to real uid
  Future<void> _migrateTempSaathiIfExists(String uid, String phone) async {
    try {
      final phoneClean = phone.replaceAll('+91', '').trim();
      final tempDoc = await FirebaseFirestore.instance
          .collection('saathis').doc(phoneClean).get();
      if (!tempDoc.exists) return;

      final tempData = tempDoc.data()!;
      // Only migrate if uid == phone number (temp admin-created doc)
      if (tempData['uid'] != phoneClean) return;

      debugPrint('📦 Migrating admin-created saathi doc: $phoneClean → $uid');

      final batch = FirebaseFirestore.instance.batch();

      // Create saathis doc with real uid
      batch.set(
        FirebaseFirestore.instance.collection('saathis').doc(uid),
        {
          ...tempData,
          'uid': uid,
          'phone': '+91$phoneClean',
          'isVerified': tempData['isVerified'] ?? false,
          'status': tempData['status'] ?? 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Create/overwrite users doc with real uid
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'uid': uid,
          'name': tempData['name'] ?? '',
          'displayName': tempData['name'] ?? '',
          'phone': '+91$phoneClean',
          'role': 'saathi',
          'village': tempData['village'] ?? '',
          'profilePhoto': '',
          'fcmToken': '',
          'isBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Delete old temp docs (phone-keyed)
    batch.delete(
  FirebaseFirestore.instance
      .collection('saathis')
      .doc(phoneClean),
);
      final tempUserDoc = await FirebaseFirestore.instance
          .collection('users').doc(phoneClean).get();
 if (tempUserDoc.exists) {
  batch.delete(
    FirebaseFirestore.instance
        .collection('users')
        .doc(phoneClean),
  );
}
      await batch.commit();
      debugPrint('✅ Migration complete: $phoneClean → $uid');
    } catch (e) {
      debugPrint('⚠️ Migration error (non-fatal): $e');
    }
  }

  Future<void> _handlePostLogin(String uid, String loginRole) async {
    setState(() => _loading = true);

    try {
      // First: check if admin pre-created a saathi record with phone as docId
      await _migrateTempSaathiIfExists(uid, widget.phone);

      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();

      if (!mounted) return;

      if (!doc.exists) {
        // Brand new user — go to registration based on login role
        if (loginRole == 'saathi') {
          _goRemoveAll(SaathiRegistrationScreen(uid: uid, phone: widget.phone));
        } else if (loginRole == 'haul_owner') {
          // Haul owners must be pre-created by admin
          if (mounted) {
            await FirebaseAuth.instance.signOut();
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'GaamHaul owner not found.\n'
                  'Please contact admin to register your vehicle.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          _goRemoveAll(CustomerRegistrationScreen(uid: uid, phone: widget.phone));
        }
        return;
      }

      final savedRole = (doc.data()!['role'] as String?) ?? 'customer';

      // Same role — just navigate
      if (savedRole == loginRole) {
        if (savedRole == 'saathi') {
          _goRemoveAll(const SaathiMainShell());
        } else if (savedRole == 'haul_owner') {
          _goRemoveAll(const HaulOwnerShell());
        } else {
          _goRemoveAll(const CustomerMainShell());
        }
        return;
      }

      // Role conflict — same phone, different role chosen
      if (!mounted) return;
      setState(() => _loading = false);

      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(children: [
            Icon(Icons.person_outline, size: 48, color: AppColors.primaryGreen),
            const SizedBox(height: 8),
            const Text('કયા રૂપે ચાલુ કરવું?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const Text('Which mode to continue?',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                textAlign: TextAlign.center),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'આ નંબર પહેલેથી ${savedRole == 'saathi' ? 'Gaam Saathi' : 'Customer'} '
              'તરીકે નોંધાયેલ છે.',
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'This number is already registered as '
              '${savedRole == 'saathi' ? 'Gaam Saathi' : 'Customer'}.',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
          ]),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            // Continue as saved role
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: savedRole == 'saathi'
                      ? AppColors.primaryOrange : AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context, savedRole),
                child: Text(
                  savedRole == 'saathi'
                      ? '🛵 Gaam Saathi તરીકે ચાલુ'
                      : '👤 Customer તરીકે ચાલુ',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Switch role
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context, loginRole),
                child: Text(
                  loginRole == 'saathi'
                      ? '🛵 Saathi તરીકે Switch કરો'
                      : '👤 Customer તરીકે Switch કરો',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );

      if (!mounted || choice == null) return;
      setState(() => _loading = true);

      // Update role in Firestore if switched
      if (choice != savedRole) {
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .update({'role': choice, 'updatedAt': FieldValue.serverTimestamp()});
      }

      if (!mounted) return;

      if (choice == 'saathi') {
        // Check if saathi profile exists
        final saathiDoc = await FirebaseFirestore.instance
            .collection('saathis').doc(uid).get();
        if (!saathiDoc.exists) {
          _goRemoveAll(SaathiRegistrationScreen(uid: uid, phone: widget.phone));
        } else {
          _goRemoveAll(const SaathiMainShell());
        }
      } else {
        _goRemoveAll(const CustomerMainShell());
      }
    } catch (e) {
      debugPrint('Post-login error: $e');
      if (mounted) {
        setState(() { _loading = false; _error = 'Login error. Please try again.'; });
      }
    }
  }

  void _onDigitInput(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _color,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _color.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.sms_outlined, color: _color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.otpSent,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: _color),
              ),
              const SizedBox(height: 6),
              Text(
                'OTP sent to +91 ${widget.phone}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 46,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _color, width: 2),
                      ),
                    ),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    onChanged: (v) => _onDigitInput(i, v),
                  ),
                )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12))),
                ]),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                          AppStrings.verifyOtp,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }
}
