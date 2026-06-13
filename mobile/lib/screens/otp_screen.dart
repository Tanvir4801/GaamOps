import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'profile_setup_screen.dart';
import 'saathi/saathi_main_shell.dart';
import 'customer/customer_main_shell.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleUserCredential(widget.userCredential!));
    }
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
      await _handleUserCredential(userCred);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message ?? 'Invalid OTP. Try again.';
      });
    }
  }

  Future<void> _handleUserCredential(UserCredential cred) async {
    final uid = cred.user!.uid;
    final existing = await AuthService.getUser(uid);

    if (!mounted) return;

    if (existing == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            uid: uid,
            phone: widget.phone,
            role: widget.role,
          ),
        ),
        (_) => false,
      );
    } else if (existing.role == 'saathi') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SaathiMainShell()),
        (_) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerMainShell()),
        (_) => false,
      );
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
              Text(
                AppStrings.otpSent,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'OTP sent to +91 ${widget.phone}',
                style: const TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (i) => SizedBox(
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
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _color, width: 2),
                        ),
                      ),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      onChanged: (v) => _onDigitInput(i, v),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12)),
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
                  ),
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
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
