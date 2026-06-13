import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

class SosButton extends StatelessWidget {
  final double? lat;
  final double? lng;

  const SosButton({super.key, this.lat, this.lng});

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🚨 Emergency / ઈમર્જન્સી'),
        content: const Text('Select emergency action:'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await launchUrl(Uri.parse('tel:112'));
            },
            child: const Text('📞 112 Call', style: TextStyle(color: AppColors.error)),
          ),
          if (lat != null && lng != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final msg = Uri.encodeComponent(
                    'SOS! My location: https://maps.google.com/?q=$lat,$lng');
                await launchUrl(Uri.parse('https://wa.me/?text=$msg'));
              },
              child: const Text('📍 WhatsApp Location'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      backgroundColor: AppColors.sosRed,
      heroTag: 'sos',
      onPressed: () => _showSosDialog(context),
      child: const Text(
        'SOS',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
