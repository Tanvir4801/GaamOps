import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool get _isSaathi => widget.role == 'saathi';
  Color get _color =>
      _isSaathi ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
  List<Color> get _gradientColors => _isSaathi
      ? [const Color(0xFFBF360C), const Color(0xFFE65100)]
      : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)];

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91$phone',
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

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        Container(
          height: 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradientColors,
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BackButton(color: Colors.white),
                  const SizedBox(height: 16),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSaathi
                          ? Icons.two_wheeler
                          : Icons.person_outline,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isSaathi ? 'Saathi Login' : 'Customer Login',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Text(
                    _isSaathi ? 'Earn by Driving' : 'Book rides instantly',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 258,
          left: 0,
          right: 0,
          bottom: 0,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'મોબાઈલ નંબર / Phone Number',
                  style: TextStyle(
                      fontSize: 13,
                      color: _color,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      '+91',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2),
                        decoration: InputDecoration(
                          hintText: '00000 00000',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade300, letterSpacing: 2),
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                        ),
                      ),
                    ),
                  ),
                ]),
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
                const SizedBox(height: 24),
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
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('અથવા / OR',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ]),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.help_outline,
                        size: 16, color: Colors.grey),
                    label: Text(
                      'સમસ્યા છે? WhatsApp પર સંપર્ક કરો',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
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
        ),
      ]),
    );
  }
}
