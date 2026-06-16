import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'How do I book a ride?',
      'Open the app → Select your pickup village → Choose your destination → Tap "Find Saathi". A nearby Saathi will accept your ride.',
    ),
    (
      'What is GaamCash?',
      'GaamCash is our rewards wallet. You earn 2% cashback on every ride. Use GaamCash to pay for future rides.',
    ),
    (
      'How do I pay for rides?',
      'You can pay with Cash, UPI (GPay, PhonePe, Paytm), or GaamCash wallet. Choose at booking time.',
    ),
    (
      'My Saathi did not arrive. What do I do?',
      'Wait 2 minutes after they mark "Arrived". If they still haven\'t come, cancel the ride and rebook. You can also contact the Saathi via the tracking screen.',
    ),
    (
      'How do I cancel a ride?',
      'On the ride tracking screen, tap the ✕ button. Cancellation is free before the Saathi starts the trip.',
    ),
    (
      'How do I add Emergency Contacts?',
      'Profile → Emergency Contacts → Add up to 3 contacts. They will be alerted during an SOS.',
    ),
    (
      'Where does GaamRide operate?',
      'GaamRide currently operates in Mahuva Taluka, Surat District, Gujarat. We are expanding to more villages soon.',
    ),
    (
      'How do I become a Saathi (driver)?',
      'Download the app → Select "Gaam Saathi" → Register with your vehicle details → Wait for admin verification (usually 1–2 days).',
    ),
  ];

  Future<void> _whatsapp() async {
    final uri = Uri.parse(
        'https://wa.me/919099999999?text=Hello%20GaamRide%20Support%20-%20I%20need%20help');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _call() async {
    final uri = Uri.parse('tel:+919099999999');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact buttons
            Row(children: [
              Expanded(
                child: _ContactButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  subtitle: 'Fastest reply',
                  color: const Color(0xFF25D366),
                  onTap: _whatsapp,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactButton(
                  icon: Icons.call,
                  label: 'Call Us',
                  subtitle: '9099999999',
                  color: AppColors.primaryGreen,
                  onTap: _call,
                ),
              ),
            ]),

            const SizedBox(height: 24),

            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            ...List.generate(_faqs.length, (i) {
              final faq = _faqs[i];
              return _FAQTile(question: faq.$1, answer: faq.$2);
            }),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.support_agent_outlined,
                    color: AppColors.primaryGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Still need help?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text(
                      'Our support team replies within 2 hours on WhatsApp',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ContactButton(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: color.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(subtitle,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

class _FAQTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FAQTile({required this.question, required this.answer});

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4)
        ],
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Text(
                  widget.question,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Icon(
                _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppColors.textGrey,
              ),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              widget.answer,
              style: const TextStyle(
                  color: AppColors.textGrey, fontSize: 13, height: 1.5),
            ),
          ),
      ]),
    );
  }
}
