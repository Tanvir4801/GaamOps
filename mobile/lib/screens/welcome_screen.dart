import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        // Full green top section with gradient
        Container(
          height: size.height * 0.58,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B5E20),
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
              ],
            ),
          ),
        ),

        // White bottom section with rounded top
        Positioned(
          bottom: 0,
          child: Container(
            width: size.width,
            height: size.height * 0.48,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
          ),
        ),

        // Full content
        SafeArea(
          child: Column(children: [
            SizedBox(height: size.height * 0.06),

            // Logo icon box
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.electric_rickshaw,
                  color: Colors.white, size: 56),
            ),
            const SizedBox(height: 16),

            // App name
            const Text(
              AppStrings.appName,
              style: TextStyle(
                  fontSize: 38, fontWeight: FontWeight.bold,
                  color: Colors.white, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            const Text(AppStrings.taglineGu,
                style: TextStyle(fontSize: 17, color: Colors.white70)),
            const Text(AppStrings.taglineEn,
                style: TextStyle(fontSize: 13, color: Colors.white54)),

            SizedBox(height: size.height * 0.08),

            // Buttons in white section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
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

                // Saathi button
                _WelcomeButton(
                  icon: Icons.two_wheeler,
                  color: AppColors.primaryOrange,
                  titleGu: 'Gaam Saathi બનો',
                  titleEn: 'Become a Driver & Earn',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen(role: 'saathi')),
                  ),
                ),

                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text(AppStrings.serviceArea,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textGrey)),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
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
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: color.withAlpha(80),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleGu,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(titleEn,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white70, size: 16),
            ]),
          ),
        ),
      ),
    );
  }
}
