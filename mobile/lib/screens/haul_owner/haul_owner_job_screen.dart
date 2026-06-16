import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_booking_model.dart';
import '../../services/haul_service.dart';

class HaulOwnerJobScreen extends StatefulWidget {
  final HaulBookingModel booking;
  final VoidCallback onComplete;

  const HaulOwnerJobScreen({
    super.key,
    required this.booking,
    required this.onComplete,
  });

  @override
  State<HaulOwnerJobScreen> createState() => _HaulOwnerJobScreenState();
}

class _HaulOwnerJobScreenState extends State<HaulOwnerJobScreen> {
  StreamSubscription? _sub;
  HaulBookingModel? _booking;
  Timer? _elapsedTimer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _sub = HaulService.watchBooking(widget.booking.bookingId).listen((snap) {
      if (!snap.exists || !mounted) return;
      final b = HaulBookingModel.fromFirestore(snap);
      setState(() => _booking = b);
      if (b.status == HaulBookingModel.started && _elapsedTimer == null) {
        _startElapsedTick();
      }
    });
  }

  void _startElapsedTick() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _setLoading(Future<void> Function() fn) async {
    setState(() => _loading = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startWork() async {
    await _setLoading(() => HaulService.startBooking(widget.booking.bookingId));
    _startElapsedTick();
  }

  Future<void> _completeJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete Job?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Mark this haul job as complete?\n\nJob પૂર્ણ કરો?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not yet')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _setLoading(
          () => HaulService.completeBooking(widget.booking.bookingId));
      widget.onComplete();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _cancelJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Job?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Job',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _setLoading(() => HaulService.cancelBooking(
          widget.booking.bookingId, 'Cancelled by owner'));
      widget.onComplete();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _callCustomer() async {
    final phone = (_booking ?? widget.booking).customerPhone;
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking ?? widget.booking;
    final isAccepted = b.status == HaulBookingModel.accepted;
    final isStarted  = b.status == HaulBookingModel.started;
    final elapsed    = b.elapsed;
    final fraction   = b.elapsedFraction;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Active Job',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Vehicle + customer header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(10), blurRadius: 10)
              ],
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.bgOrange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(b.vehicleEmoji,
                        style: const TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.vehicleTypeLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(b.vehicleNumber,
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 12)),
                    ],
                  ),
                ),
                _statusBadge(b.status),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Customer
              Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.bgOrange,
                  child: Text(
                    b.customerName.isNotEmpty
                        ? b.customerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(b.customerPhone,
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _callCustomer,
                  icon: const Icon(Icons.call, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 14),

          // Job details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(8), blurRadius: 8)
              ],
            ),
            child: Column(children: [
              _detailRow(Icons.location_on_outlined, 'Location',
                  b.pickupVillage),
              const Divider(height: 24),
              _detailRow(Icons.inventory_2_outlined, 'Load Description',
                  b.loadDescription.isNotEmpty
                      ? b.loadDescription : '—'),
              const Divider(height: 24),
              _detailRow(Icons.timer_outlined, 'Duration', b.durationLabel),
              const Divider(height: 24),
              _detailRow(Icons.currency_rupee, 'Your Earnings',
                  '₹${b.ownerEarnings.toStringAsFixed(0)}',
                  color: AppColors.primaryOrange,
                  bold: true),
            ]),
          ),

          const SizedBox(height: 14),

          // Elapsed timer (when started)
          if (isStarted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFF57C00)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                const Text('⏱ Work in Progress · Time Elapsed',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(elapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 10,
                    backgroundColor: Colors.white.withAlpha(60),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(fraction * 100).toInt()}% of ${b.durationLabel} used',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // Action button
          if (_loading) ...[
            const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange),
            ),
          ] else if (isAccepted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.route_outlined,
                    color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Head to ${b.pickupVillage}. '
                    'Press Start Work when you arrive.',
                    style: const TextStyle(
                        color: Colors.blue, fontSize: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _bigButton(
              label: '🚛 Start Work · કામ ચાલુ',
              color: AppColors.primaryOrange,
              onTap: _startWork,
            ),
          ] else if (isStarted) ...[
            _bigButton(
              label: '✓ Complete Job · પૂર્ણ',
              color: AppColors.primaryGreen,
              onTap: _completeJob,
            ),
          ],

          const SizedBox(height: 8),
          TextButton(
            onPressed: _cancelJob,
            child: const Text('Cancel Job · રદ',
                style: TextStyle(
                    color: AppColors.error, fontSize: 12)),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _statusBadge(String status) {
    String label;
    Color color;
    switch (status) {
      case HaulBookingModel.accepted:
        label = 'Confirmed';
        color = Colors.blue;
        break;
      case HaulBookingModel.started:
        label = 'Working';
        color = AppColors.primaryOrange;
        break;
      default:
        label = status;
        color = AppColors.textGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {Color? color, bool bold = false}) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primaryOrange),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              color: AppColors.textGrey, fontSize: 13)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 16 : 13,
              color: color ?? AppColors.textDark)),
    ]);
  }

  Widget _bigButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }
}

