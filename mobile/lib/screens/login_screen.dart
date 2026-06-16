import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'otp_screen.dart';
import 'auth/customer_registration_screen.dart';
import 'auth/saathi_registration_screen.dart';
import 'customer/customer_main_shell.dart';
import 'saathi/saathi_main_shell.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  bool _googleLoading = false;
  String? _error;

  bool get _isSaathi    => widget.role == 'saathi';
  bool get _isHaulOwner => widget.role == 'haul_owner';

  Color get _color {
    if (_isSaathi)    return const Color(0xFFE65100);
    if (_isHaulOwner) return const Color(0xFF5D4037);
    return const Color(0xFF2E7D32);
  }

  Color get _darkColor {
    if (_isSaathi)    return const Color(0xFFBF360C);
    if (_isHaulOwner) return const Color(0xFF3E2723);
    return const Color(0xFF1B5E20);
  }

  String get _title {
    if (_isSaathi)    return 'Saathi Login';
    if (_isHaulOwner) return 'Haul Owner Login';
    return 'Customer Login';
  }

  String get _subtitle {
    if (_isSaathi)    return 'Earn by Driving';
    if (_isHaulOwner) return 'વાહન ભાડે આપો / Rent Your Vehicle';
    return 'Book rides instantly';
  }

  IconData get _icon {
    if (_isSaathi)    return Icons.two_wheeler;
    if (_isHaulOwner) return Icons.local_shipping_outlined;
    return Icons.person_outline;
  }

  String? _validate(String phone) {
    if (phone.length != 10) return 'Valid 10-digit number enter karao';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      return 'Valid Indian mobile number enter karao';
    }
    return null;
  }

  Future<void> _sendOTP() async {
    final phone = _phoneCtrl.text.trim();
    final err = _validate(phone);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91$phone',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phone: phone,
                role: widget.role,
                verificationId: '',
                userCredential: userCred,
              ),
            ),
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = e.message ?? 'Verification failed. Try again.';
          });
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phone: phone,
                role: widget.role,
                verificationId: verificationId,
              ),
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  void _goRemoveAll(Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      final userCred = await AuthService.googleSignIn();
      if (userCred == null) {
        if (mounted) setState(() => _googleLoading = false);
        return;
      }
      final uid = userCred.user!.uid;
      final email = userCred.user!.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();

      if (!mounted) return;

      if (!doc.exists) {
        _goRemoveAll(CustomerRegistrationScreen(uid: uid, phone: email));
        return;
      }

      final savedRole = (doc.data()!['role'] as String?) ?? 'customer';
      if (savedRole == 'saathi') {
        final saathiDoc = await FirebaseFirestore.instance
            .collection('saathis').doc(uid).get();
        if (!saathiDoc.exists) {
          _goRemoveAll(SaathiRegistrationScreen(uid: uid, phone: email));
        } else {
          _goRemoveAll(const SaathiMainShell());
        }
      } else {
        _goRemoveAll(const CustomerMainShell());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _googleLoading = false;
          _error = 'Google sign-in failed. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── TOP GRADIENT HEADER ───────────────────────────
            Container(
              width: double.infinity,
              height: size.height * 0.40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_darkColor, _color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _icon,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── BOTTOM WHITE CONTENT ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'મોબાઈલ નંબર / Phone Number',
                    style: TextStyle(
                      fontSize: 13,
                      color: _color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Phone input row
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: const Text(
                            '+91',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: '00000 00000',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 20,
                                letterSpacing: 2,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 18),
                            ),
                            onSubmitted: (_) => _sendOTP(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 12)),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 8),
                  Text(
                    'OTP ચકાસણી માટે વપરાશ થશે',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400),
                  ),

                  const SizedBox(height: 28),

                  // Send OTP button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        elevation: 4,
                        shadowColor: _color.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _sendOTP,
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'OTP મોકલી રહ્યા છીએ...',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                              ],
                            )
                          : const Text(
                              'OTP મોકલો / Send OTP',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(children: [
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('અથવા / OR',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                  ]),

                  const SizedBox(height: 20),

                  // Google Sign-In button — customers only
                  if (!_isSaathi && !_isHaulOwner) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.white,
                          elevation: 0,
                        ),
                        onPressed: (_googleLoading || _isLoading) ? null : _googleSignIn,
                        child: _googleLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primaryGreen),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 22,
                                    height: 22,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.g_mobiledata,
                                      size: 26,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Google સાથે ચાલુ કરો / Continue with Google',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3C4043),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 4),
                  ],

                  Center(
                    child: TextButton.icon(
                      icon: Icon(Icons.help_outline,
                          size: 16, color: Colors.grey.shade400),
                      label: Text(
                        'સમસ્યા છે? WhatsApp પર સંપર્ક કરો',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(
                            'https://wa.me/919099999999?text=GaamRide+account+help+needed');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
