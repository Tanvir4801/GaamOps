import 'package:flutter/material.dart';
import '../login_screen.dart';

class BecomeSaathiScreen extends StatelessWidget {
  const BecomeSaathiScreen({super.key});

  static const _benefits = [
    {'emoji': '💵', 'title': 'તમારી ગાડી, તમારી કમાણી', 'sub': 'Your vehicle, your income — set your own hours'},
    {'emoji': '📱', 'title': 'સરળ App Interface', 'sub': 'Easy Gujarati app — even for non-tech users'},
    {'emoji': '🗺️', 'title': 'ગામ-ગામ Routes', 'sub': 'Local routes only — no highway pressure'},
    {'emoji': '⏰', 'title': 'Flexible Hours', 'sub': 'Work when you want, rest when you want'},
    {'emoji': '🤝', 'title': 'ગામ Support', 'sub': 'Local WhatsApp support in Gujarati'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Orange hero header
        Container(
          height: MediaQuery.of(context).size.height * 0.45,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFBF360C), Color(0xFFE65100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            Positioned(top: -40, right: -40,
              child: Container(width: 200, height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),
            Positioned(top: 80, left: -60,
              child: Container(width: 220, height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04), shape: BoxShape.circle))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('GaamRide Saathi\nબનો! 🛵',
                    style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold,
                      color: Colors.white, height: 1.2)),
                  const SizedBox(height: 8),
                  const Text('ગામડામાં ડ્રાઇવ કરો, પૈસા કમાઓ',
                    style: TextStyle(fontSize: 16, color: Colors.white70)),
                ]),
              ),
            ),
          ]),
        ),

        // White bottom sheet
        DraggableScrollableSheet(
          initialChildSize: 0.60,
          minChildSize: 0.60,
          maxChildSize: 0.95,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                // Drag handle
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),

                // Earnings highlight
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE9E7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Daily Earnings', style: TextStyle(color: Colors.grey)),
                      const Text('₹400 – ₹800',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                      const Text('per day on average',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ])),
                    const Text('💰', style: TextStyle(fontSize: 50)),
                  ]),
                ),

                const SizedBox(height: 24),
                const Text('Benefits / ફ઺ʑدو',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                ..._benefits.map((b) => _BenefitRow(b)),

                const SizedBox(height: 24),

                // Testimonial
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(children: [
                    Row(children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE65100),
                        child: Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Ramesh Patel', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Kos Village · Bike Saathi',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      const Spacer(),
                      Row(children: List.generate(5, (_) =>
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16))),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      '"GaamRide join કર્યા પછી દરરોજ 300–500 '
                      'રૂ કમાઉ છું. ગામડામાં આ app ખૂબ useful છે!"',
                      style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic, height: 1.4)),
                  ]),
                ),

                const SizedBox(height: 24),

                // CTA
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      elevation: 4,
                      shadowColor: const Color(0xFFE65100).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen(role: 'saathi'))),
                    child: const Text('હવે Register કરો / Sign Up Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 12),
                const Center(child: Text('Free to join · No monthly fee',
                  style: TextStyle(fontSize: 12, color: Colors.grey))),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final Map<String, String> b;
  const _BenefitRow(this.b);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFBE9E7),
            borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(b['emoji']!, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b['title']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(b['sub']!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
        ])),
      ]),
    );
  }
}
