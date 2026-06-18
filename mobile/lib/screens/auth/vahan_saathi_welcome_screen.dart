import 'package:flutter/material.dart';
import '../login_screen.dart';

class VahanSaathiWelcomeScreen extends StatefulWidget {
  const VahanSaathiWelcomeScreen({super.key});

  @override
  State<VahanSaathiWelcomeScreen> createState() =>
      _VahanSaathiWelcomeScreenState();
}

class _VahanSaathiWelcomeScreenState extends State<VahanSaathiWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  int _pageIndex = 0;

  static const _pages = [
    {
      'emoji': '🚚',
      'titleGu': 'તમારું વાહન,\nતમારી આવક',
      'titleEn': 'Your vehicle, your income',
      'subGu': 'મિની ટ્રક, ટેમ્પો અને ટ્રેક્ટર — GaamHaul સાથે વધુ બુકિંગ.',
    },
    {
      'emoji': '📦',
      'titleGu': 'ગ્રામ્ય\nપરિવહન',
      'titleEn': 'Village-to-village freight',
      'subGu': 'ખેતી, ઘર-ખોરાક, ઉત્પાદન — સ્થાનિક માલ પરિવહન.',
    },
    {
      'emoji': '💰',
      'titleGu': '₹10,000+\nમાસિક',
      'titleEn': 'Extra monthly income',
      'subGu': 'સ્થાનિક બુકિંગ દ્વારા વધારાની નિયમિત આવક.',
    },
    {
      'emoji': '📱',
      'titleGu': 'સરળ\nGujrati App',
      'titleEn': 'Easy Gujarati interface',
      'subGu': 'ઓટો-Accept, Real-time Tracking, ઝડપી Payment.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _slide = Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  void _changePage(int i) {
    _ctrl.forward(from: 0);
    setState(() => _pageIndex = i);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_pageIndex];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3E2723), Color(0xFF5D4037), Color(0xFF795548)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          Positioned(top: -50, right: -50,
            child: Container(width: 220, height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle))),
          Positioned(bottom: 200, left: -60,
            child: Container(width: 240, height: 240,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle))),

          SafeArea(child: Column(children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),

            const Spacer(),

            FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(children: [
                    Text(page['emoji']!,
                        style: const TextStyle(fontSize: 68)),
                    const SizedBox(height: 20),
                    Text(page['titleGu']!,
                      style: const TextStyle(
                        fontSize: 34, fontWeight: FontWeight.bold,
                        color: Colors.white, height: 1.2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(page['titleEn']!,
                      style: const TextStyle(fontSize: 13, color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(page['subGu']!,
                      style: const TextStyle(
                          fontSize: 15, color: Colors.white70, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ),
            ),

            const Spacer(),

            // Page dots
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) =>
                GestureDetector(
                  onTap: () => _changePage(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _pageIndex == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _pageIndex == i
                          ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Benefit chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const [
                  _Chip('📦 માલ પરિવહન'),
                  _Chip('🌾 ખેતી સેવા'),
                  _Chip('💰 ઝડપી ચુકવણી'),
                  _Chip('📱 ગુજરાતી App'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Trust row
            Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              _Trust('✓ Verified ગ્રાહકો'),
              SizedBox(width: 20),
              _Trust('✓ ઝડપી ચુકવણી'),
              SizedBox(width: 20),
              _Trust('✓ 24/7 Support'),
            ]),

            const SizedBox(height: 28),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5D4037),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(role: 'haul_owner')),
                  ),
                  child: const Text(
                    'વાહન જોડો — Register Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Text('Free to join · No monthly fee · Local support',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
            const SizedBox(height: 28),
          ])),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: const TextStyle(fontSize: 12, color: Colors.white,
            fontWeight: FontWeight.w500)),
  );
}

class _Trust extends StatelessWidget {
  final String label;
  const _Trust(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 11, color: Colors.white60));
}
