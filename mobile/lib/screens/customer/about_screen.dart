import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.0.0';
  static const _buildNum = '2024.1';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('About GaamRide',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // App logo card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), AppColors.primaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withAlpha(50), width: 1.5),
                  ),
                  child: const Icon(Icons.electric_rickshaw,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppStrings.taglineGu,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 2),
                const Text(
                  AppStrings.taglineEn,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v$_version (Build $_buildNum)',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            _infoCard(isDark, [
              _infoRow(
                  Icons.location_on_outlined, 'Service Area', 'Mahuva Taluka, Surat, Gujarat'),
              _infoRow(Icons.phone_outlined, 'Support', '+91 90999 99999'),
              _infoRow(Icons.email_outlined, 'Email', 'support@gaamride.in'),
            ]),

            const SizedBox(height: 16),

            _infoCard(isDark, [
              _infoRow(Icons.business_outlined, 'Company', 'GaamRide Technologies Pvt. Ltd.'),
              _infoRow(Icons.flag_outlined, 'Founded', '2024 · Mahuva, Gujarat'),
              _infoRow(Icons.group_outlined, 'Mission',
                  'Affordable rural transport for every village'),
            ]),

            const SizedBox(height: 16),

            // Links
            _linkTile(
              Icons.privacy_tip_outlined,
              'Privacy Policy',
              'https://gaamride.in/privacy',
              isDark,
            ),
            const SizedBox(height: 8),
            _linkTile(
              Icons.article_outlined,
              'Terms of Service',
              'https://gaamride.in/terms',
              isDark,
            ),
            const SizedBox(height: 8),
            _linkTile(
              Icons.star_outline,
              'Rate on Play Store',
              'https://play.google.com/store',
              isDark,
            ),

            const SizedBox(height: 32),

            Text(
              '❤️ Made with love in Mahuva, Gujarat',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : AppColors.textGrey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '© 2024 GaamRide. All rights reserved.',
              style: TextStyle(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  fontSize: 11),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(bool isDark, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textGrey)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _linkTile(IconData icon, String label, String url, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4)
          ],
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textGrey),
        ]),
      ),
    );
  }
}
