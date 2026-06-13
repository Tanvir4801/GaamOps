import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../utils/date_formatter.dart';

class RideReceiptScreen extends StatefulWidget {
  final RideModel ride;
  const RideReceiptScreen({super.key, required this.ride});

  @override
  State<RideReceiptScreen> createState() => _RideReceiptScreenState();
}

class _RideReceiptScreenState extends State<RideReceiptScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _shareReceipt() async {
    final text = '''
GaamRide Receipt 🛵
─────────────────────
Route: ${widget.ride.pickupVillage} → ${widget.ride.destinationVillage}
Saathi: ${widget.ride.saathiName}
Date: ${DateFormatter.format(widget.ride.createdAt)}
Distance: ${widget.ride.distance.toStringAsFixed(1)} km
Fare Paid: ₹${widget.ride.fare.toStringAsFixed(0)} (Cash)
Ride ID: ${widget.ride.rideId.substring(0, 8).toUpperCase()}
─────────────────────
Thank you for using GaamRide!
''';
    final uri = Uri(
      scheme: 'https',
      host: 'api.whatsapp.com',
      path: '/send',
      queryParameters: {'text': text},
    );
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _copyRideId() {
    Clipboard.setData(ClipboardData(text: widget.ride.rideId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride ID copied'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ride;
    final isCompleted = r.status == RideModel.completed;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Ride Receipt',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primaryGreen),
            onPressed: _shareReceipt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              children: [
                _ReceiptCard(
                  ride: r,
                  isCompleted: isCompleted,
                  onCopyId: _copyRideId,
                ),
                const SizedBox(height: 16),
                _FareBreakdown(ride: r),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share, color: Colors.white, size: 18),
                    label: const Text('Share via WhatsApp',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _shareReceipt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final RideModel ride;
  final bool isCompleted;
  final VoidCallback onCopyId;

  const _ReceiptCard({
    required this.ride,
    required this.isCompleted,
    required this.onCopyId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12)],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryGreen, Color(0xFF0E7C5B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.cancel_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '₹${ride.fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCompleted ? 'Paid in Cash' : ride.status.toUpperCase(),
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _Row(icon: Icons.location_on_outlined,
                    label: 'From', value: ride.pickupVillage),
                const SizedBox(height: 12),
                _Row(icon: Icons.flag_outlined,
                    label: 'To', value: ride.destinationVillage),
                const Divider(height: 28),
                _Row(icon: Icons.person_outline,
                    label: 'Saathi', value: ride.saathiName),
                const SizedBox(height: 12),
                _Row(icon: Icons.electric_rickshaw_outlined,
                    label: 'Vehicle', value: ride.vehicleType.isNotEmpty ? ride.vehicleType : '—'),
                const SizedBox(height: 12),
                _Row(icon: Icons.calendar_today_outlined,
                    label: 'Date', value: DateFormatter.format(ride.createdAt)),
                const SizedBox(height: 12),
                _Row(icon: Icons.straighten_outlined,
                    label: 'Distance',
                    value: '${ride.distance.toStringAsFixed(1)} km'),
                if (ride.rating > 0) ...[
                  const SizedBox(height: 12),
                  _Row(
                    icon: Icons.star_rounded,
                    label: 'Your Rating',
                    value: '★' * ride.rating,
                    valueColor: Colors.amber,
                  ),
                ],
                const Divider(height: 28),
                GestureDetector(
                  onTap: onCopyId,
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_outlined,
                          color: AppColors.textGrey, size: 18),
                      const SizedBox(width: 10),
                      const Text('Ride ID',
                          style: TextStyle(
                              color: AppColors.textGrey, fontSize: 13)),
                      const Spacer(),
                      Text(
                        ride.rideId.substring(0, 8).toUpperCase(),
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded,
                          size: 14, color: AppColors.textGrey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FareBreakdown extends StatelessWidget {
  final RideModel ride;
  const _FareBreakdown({required this.ride});

  @override
  Widget build(BuildContext context) {
    final baseFare = 10.0;
    final perKm = ride.distance > 0 ? (ride.fare - baseFare) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fare Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _BreakRow('Base fare', '₹${baseFare.toStringAsFixed(0)}'),
          const SizedBox(height: 6),
          _BreakRow('Distance (${ride.distance.toStringAsFixed(1)} km)',
              '₹${perKm.toStringAsFixed(0)}'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('₹${ride.fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primaryGreen)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.money, color: AppColors.primaryGreen, size: 14),
                SizedBox(width: 5),
                Text('Paid in Cash',
                    style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _Row(
      {required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textGrey, size: 18),
        const SizedBox(width: 10),
        Text(label,
            style:
                const TextStyle(color: AppColors.textGrey, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? AppColors.textDark)),
      ],
    );
  }
}

class _BreakRow extends StatelessWidget {
  final String label;
  final String value;
  const _BreakRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }
}
