import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../constants/app_colors.dart';
import 'upi_setup_screen.dart';

/// Displays a scannable UPI QR code for the saathi.
/// Shows instructions for the customer and the fare amount prominently.
class UpiQrScreen extends StatelessWidget {
  final String upiId;
  final String upiName;
  final double fare;

  const UpiQrScreen({
    super.key,
    required this.upiId,
    required this.upiName,
    required this.fare,
  });

  String get _upiString {
    final encodedName = Uri.encodeComponent(upiName.isNotEmpty ? upiName : 'Saathi');
    final amt = fare.toStringAsFixed(2);
    return 'upi://pay?pa=$upiId&pn=$encodedName&am=$amt&cu=INR&tn=GaamRide+Ride+Payment';
  }

  @override
  Widget build(BuildContext context) {
    // No UPI ID set up yet
    if (upiId.isEmpty) {
      return _NoUpiSetup(upiName: upiName);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Instruction
        Text(
          'Ask customer to scan with any UPI app',
          style: TextStyle(
              fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 14),

        // QR card with dashed border
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Dashed border container around QR
              CustomPaint(
                painter: _DashedBorderPainter(color: const Color(0xFFf97316)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: _upiString,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Saathi name + UPI ID
              if (upiName.isNotEmpty)
                Text(
                  upiName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              Text(
                upiId,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontFamily: 'monospace'),
              ),

              const SizedBox(height: 12),

              // Fare badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFf97316).withAlpha(60)),
                ),
                child: Text(
                  '₹${fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFf97316)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // UPI app icons row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AppChip('G', const Color(0xFF4285F4), 'GPay'),
            const SizedBox(width: 8),
            _AppChip('Pe', const Color(0xFF5F259F), 'PhonePe'),
            const SizedBox(width: 8),
            _AppChip('P', const Color(0xFF002970), 'Paytm'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Open any of these apps to scan',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

class _NoUpiSetup extends StatelessWidget {
  final String upiName;
  const _NoUpiSetup({required this.upiName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Set up your UPI ID to accept online payments',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('Set up UPI',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => UpiSetupScreen(saathiName: upiName))),
          ),
        ),
      ],
    );
  }
}

class _AppChip extends StatelessWidget {
  final String label;
  final Color color;
  final String name;
  const _AppChip(this.label, this.color, this.name);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        const SizedBox(height: 3),
        Text(name,
            style:
                TextStyle(fontSize: 9, color: Colors.grey[500])),
      ],
    );
  }
}

/// Dashed border painter for the QR container.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(140)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const gap = 5.0;
    const dash = 5.0;
    const r = 12.0;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(r));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, (dist + dash).clamp(0, metric.length)),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
