import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'login_screen.dart';
import 'auth/become_saathi_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── TOP GREEN SECTION (55% of screen) ────────────
          Container(
            height: size.height * 0.55,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF43A047),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(48),
                bottomRight: Radius.circular(48),
              ),
            ),
            child: Stack(children: [
              // Decorative background circles for depth
              Positioned(
                top: -40, right: -40,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: 80, left: -60,
                child: Container(
                  width: 240, height: 240,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -20, right: 30,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Main content
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.electric_rickshaw,
                          color: Colors.white, size: 56),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      AppStrings.taglineGu,
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      AppStrings.taglineEn,
                      style: TextStyle(fontSize: 13, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          // ── BOTTOM WHITE SECTION (45% of screen) ─────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                children: [
                  // Customer button
                  _WelcomeButton(
                    icon: Icons.person_outline,
                    color: AppColors.primaryGreen,
                    titleGu: 'Customer તરીકે ચાલુ કરો',
                    titleEn: 'Continue as Customer',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen(role: 'customer')),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Saathi button — goes to BecomeSaathiScreen first
                  _WelcomeButton(
                    icon: Icons.two_wheeler,
                    color: AppColors.primaryOrange,
                    titleGu: 'Gaam Saathi બનો',
                    titleEn: 'Become a Driver & Earn',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BecomeSaathiScreen()),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Haul Owner button
                  _WelcomeButton(
                    icon: Icons.local_shipping,
                    color: const Color(0xFF5D4037),
                    titleGu: 'વાહન માલિક — GaamHaul',
                    titleEn: 'Vehicle Owner — Rent your truck/tractor',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const LoginScreen(role: 'haul_owner')),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Trust badges row
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _TrustBadge(Icons.verified_user_outlined, 'Safe & Secure'),
                    Container(height: 30, width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.grey.shade200),
                    _TrustBadge(Icons.support_agent_outlined, 'Local Support'),
                    Container(height: 30, width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.grey.shade200),
                    _TrustBadge(Icons.currency_rupee_outlined, 'Fair Pricing'),
                  ]),

                  const SizedBox(height: 14),

                  // Social proof
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FBF0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB8E0B8)),
                    ),
                    child: Row(children: [
                      const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      const Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '"GaamRide આવ્યા પછી ગામડામાં ટ્રાન્સપોર્ટ સરળ!'
                            '"',
                            style: TextStyle(fontSize: 11,
                                color: Color(0xFF1B5E20),
                                fontStyle: FontStyle.italic),
                          ),
                          Text('— Mahuva Taluka User',
                              style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      )),
                    ]),
                  ),

                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.serviceArea,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: AppColors.primaryGreen),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
          fontSize: 10, color: Colors.grey.shade600,
          fontWeight: FontWeight.w500)),
    ]);
  }
}

class _WelcomeButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titleGu;
  final String titleEn;
  final VoidCallback onTap;

  const _WelcomeButton({
    required this.icon,
    required this.color,
    required this.titleGu,
    required this.titleEn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: color.withAlpha(80),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleGu,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text(titleEn,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
