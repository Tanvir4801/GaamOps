import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../welcome_screen.dart';
import 'haul_owner_shell.dart';

class VahanSaathiPendingScreen extends StatefulWidget {
  final String uid;
  const VahanSaathiPendingScreen({super.key, required this.uid});

  @override
  State<VahanSaathiPendingScreen> createState() =>
      _VahanSaathiPendingScreenState();
}

class _VahanSaathiPendingScreenState extends State<VahanSaathiPendingScreen>
    with TickerProviderStateMixin {
  StreamSubscription? _sub;
  String _status = 'pending';
  String _rejectionReason = '';
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
        lowerBound: 0.85,
        upperBound: 1.0)
      ..repeat(reverse: true);
    _watchStatus();
  }

  void _watchStatus() {
    _sub = FirebaseFirestore.instance
        .collection('haul_vehicles')
        .doc(widget.uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data()!;
      final status = (data['status'] as String?) ?? 'pending';
      setState(() {
        _status = status;
        _rejectionReason = (data['rejectionReason'] as String?) ?? '';
      });
      if (status == 'approved' || status == 'active') {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HaulOwnerShell()),
              (_) => false,
            );
          }
        });
      }
    });
  }

  Future<void> _logout() async {
    _sub?.cancel();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3E2723), Color(0xFF6D4C41)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                if (_status == 'pending') ...[
                  ScaleTransition(
                    scale: _pulseCtrl,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2)),
                      child: const Icon(Icons.hourglass_empty_rounded,
                          color: Colors.amber, size: 50),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('⏳ ચકાસણી હેઠળ',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'તમારું એકાઉન્ટ ચકાસણી હેઠળ છે.\nઅંદાજિત સમય: 24–48 કલાક',
                    style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  _StatusBadge(label: '🟡 Pending Review', color: Colors.amber),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16)),
                    child: const Column(children: [
                      _StepRow('✅', 'Registration Complete'),
                      _StepRow('⏳', 'Documents under review'),
                      _StepRow('⬜', 'Approval & Activation'),
                    ]),
                  ),
                ] else if (_status == 'rejected') ...[
                  const Icon(Icons.cancel_rounded,
                      color: Colors.redAccent, size: 80),
                  const SizedBox(height: 20),
                  const Text('Application Rejected',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                  const SizedBox(height: 12),
                  if (_rejectionReason.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent)),
                      child: Text(
                        'કારણ: $_rejectionReason',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Support: contact admin for help.',
                      style: TextStyle(color: Colors.white60, fontSize: 13)),
                ] else ...[
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.greenAccent, size: 80),
                  const SizedBox(height: 20),
                  const Text('✅ Approved! Entering app...',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: Colors.white),
                ],

                const Spacer(),

                OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.white60),
                  label: const Text('Sign Out',
                      style: TextStyle(color: Colors.white60)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _logout,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color)),
    child: Text(label,
        style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 14)),
  );
}

class _StepRow extends StatelessWidget {
  final String icon;
  final String label;
  const _StepRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
    ]),
  );
}
