import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class UpiSetupScreen extends StatefulWidget {
  /// Pre-filled values from existing Firestore data, if any.
  final String currentUpiId;
  final String currentUpiName;
  final String saathiName;

  const UpiSetupScreen({
    super.key,
    this.currentUpiId = '',
    this.currentUpiName = '',
    this.saathiName = '',
  });

  @override
  State<UpiSetupScreen> createState() => _UpiSetupScreenState();
}

class _UpiSetupScreenState extends State<UpiSetupScreen> {
  late final TextEditingController _upiIdCtrl;
  late final TextEditingController _upiNameCtrl;
  bool _saving = false;
  String? _error;

  static const _hints = [
    'PhonePe: 9876543210@ybl',
    'GPay: 9876543210@okicici',
    'Paytm: 9876543210@paytm',
    'BHIM: 9876543210@upi',
  ];

  @override
  void initState() {
    super.initState();
    _upiIdCtrl = TextEditingController(text: widget.currentUpiId);
    _upiNameCtrl = TextEditingController(
        text: widget.currentUpiName.isNotEmpty
            ? widget.currentUpiName
            : widget.saathiName);
  }

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    super.dispose();
  }

  bool _isValidUpi(String id) {
    // Basic UPI format: something@provider
    return RegExp(r'^[a-zA-Z0-9.\-_]+@[a-zA-Z]+$').hasMatch(id.trim());
  }

  Future<void> _save() async {
    final upiId = _upiIdCtrl.text.trim();
    final upiName = _upiNameCtrl.text.trim();

    if (upiId.isEmpty) {
      setState(() => _error = 'Please enter your UPI ID');
      return;
    }
    if (!_isValidUpi(upiId)) {
      setState(() => _error = 'Enter a valid UPI ID (e.g. 9876543210@ybl)');
      return;
    }
    if (upiName.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('saathis')
          .doc(uid)
          .update({
        'upiId': upiId,
        'upiName': upiName,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ UPI ID saved. Customers can now scan to pay you.'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to save: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.qr_code_2_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UPI Direct Payments',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text('Customers scan your QR and pay you directly',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    '💡 Money goes straight to your bank account. GaamRide doesn\'t touch it.',
                    style: TextStyle(
                        color: Colors.white.withAlpha(200), fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // UPI ID
            const Text('Your UPI ID',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _upiIdCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'yourname@ybl or 9876543210@paytm',
                hintStyle: const TextStyle(color: AppColors.textLight),
                helperText: 'Find this in your GPay / PhonePe / Paytm settings',
                helperStyle: const TextStyle(fontSize: 11),
                prefixIcon:
                    const Icon(Icons.alternate_email, color: AppColors.textGrey),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFF1D4ED8), width: 2)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Name on UPI
            const Text('Name on UPI account',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _upiNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Your name as in your UPI app',
                hintStyle: const TextStyle(color: AppColors.textLight),
                prefixIcon:
                    const Icon(Icons.person_outline, color: AppColors.textGrey),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFF1D4ED8), width: 2)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // Hint chips
            const Text('Common UPI ID formats:',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hints.map((h) => GestureDetector(
                onTap: () {
                  final parts = h.split(': ');
                  if (parts.length == 2) {
                    _upiIdCtrl.text = parts[1];
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFBFDBFE), width: 1),
                  ),
                  child: Text(h,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF1D4ED8))),
                ),
              )).toList(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withAlpha(40))),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Save UPI ID',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
