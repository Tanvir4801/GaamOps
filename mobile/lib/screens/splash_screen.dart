import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'welcome_screen.dart';
import 'maintenance_screen.dart';
import 'customer/customer_main_shell.dart';
import 'saathi/saathi_main_shell.dart';
import 'haul_owner/haul_owner_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _taglineCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;

  int _currentTagline = 0;
  bool _showTagline = false;

  static const _taglines = [
    {'gu': 'ગામને જોડે, લોકોને નજીક લાવે.', 'en': 'Connecting villages, bringing people closer.', 'emoji': '🏘️'},
    {'gu': 'જ\'યાં રસ્તો, ત\'યાં GaamRide.', 'en': 'Where there\'s a road, there\'s GaamRide.', 'emoji': '🛣️'},
    {'gu': 'તમારી સફર, અમારી જવાબદારી.', 'en': 'Your journey, our responsibility.', 'emoji': '❤️'},
    {'gu': 'ઝટપટ બુકિંગ, તરત સેવા.', 'en': 'Instant booking, immediate service.', 'emoji': '⚡'},
    {'gu': 'ગામડાની જરૂરિયાત માટે બનાવેલું.', 'en': 'Built for the needs of the village.', 'emoji': '🌾'},
  ];

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));

    _taglineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeIn));
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));

    _startSequence();
  }

  Future<void> _startSequence() async {
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));

    for (int i = 0; i < _taglines.length; i++) {
      if (!mounted) return;
      setState(() { _currentTagline = i; _showTagline = true; });
      _taglineCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      await _taglineCtrl.reverse();
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _navigate();
  }

  Future<void> _navigate() async {
    try {
      final settings = await SettingsService.getSettings();
      if (!mounted) return;

      if (settings.maintenanceMode) {
        _go(const MaintenanceScreen());
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _go(const WelcomeScreen()); return; }

      final userModel = await AuthService.getUser(user.uid);
      if (!mounted) return;

      if (userModel == null) { _go(const WelcomeScreen()); return; }

      if (userModel.role == 'saathi') {
        _go(const SaathiMainShell());
      } else if (userModel.role == 'haul_owner') {
        _go(const HaulOwnerShell());
      } else {
        _go(const CustomerMainShell());
      }
    } catch (_) {
      _go(const WelcomeScreen());
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => screen), (_) => false);
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _taglineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          // Decorative background circles
          Positioned(top: -60, right: -60,
            child: Container(width: 240, height: 240,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),
          Positioned(bottom: -80, left: -40,
            child: Container(width: 280, height: 280,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04), shape: BoxShape.circle))),
          Positioned(top: 200, left: -80,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03), shape: BoxShape.circle))),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Animated logo
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Column(children: [
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30, offset: const Offset(0, 10))],
                        ),
                        child: const Icon(Icons.electric_rickshaw, color: Colors.white, size: 62),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 42, fontWeight: FontWeight.bold,
                          color: Colors.white, letterSpacing: 2,
                          shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(AppStrings.taglineGu,
                          style: TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 0.5)),
                    ]),
                  ),
                ),

                const Spacer(flex: 1),

                // Tagline box
                SizedBox(
                  height: 130,
                  child: _showTagline
                    ? FadeTransition(
                        opacity: _taglineFade,
                        child: SlideTransition(
                          position: _taglineSlide,
                          child: Container(
                            key: ValueKey(_currentTagline),
                            margin: const EdgeInsets.symmetric(horizontal: 32),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(_taglines[_currentTagline]['emoji']!,
                                  style: const TextStyle(fontSize: 30)),
                              const SizedBox(height: 8),
                              Text(_taglines[_currentTagline]['gu']!,
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.bold,
                                      color: Colors.white, height: 1.3),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 5),
                              Text(_taglines[_currentTagline]['en']!,
                                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                                  textAlign: TextAlign.center),
                            ]),
                          ),
                        ),
                      )
                    : const SizedBox(height: 130),
                ),

                const Spacer(flex: 2),

                // Dot indicators
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_taglines.length, (i) =>
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentTagline == i ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentTagline == i ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                const Text('Mahuva Taluka · Surat · Gujarat',
                    style: TextStyle(fontSize: 12, color: Colors.white38)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
