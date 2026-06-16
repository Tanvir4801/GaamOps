import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_booking_model.dart';
import '../../services/haul_service.dart';
import '../../widgets/sos_button.dart';
import 'haul_complete_screen.dart';

class HaulTrackingScreen extends StatefulWidget {
  final String bookingId;
  const HaulTrackingScreen({super.key, required this.bookingId});

  @override
  State<HaulTrackingScreen> createState() => _HaulTrackingScreenState();
}

class _HaulTrackingScreenState extends State<HaulTrackingScreen> {
  StreamSubscription? _sub;
  HaulBookingModel? _booking;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _sub = HaulService.watchBooking(widget.bookingId).listen((snap) {
      if (!snap.exists || !mounted) return;
      final b = HaulBookingModel.fromFirestore(snap);
      setState(() => _booking = b);
      if (b.status == HaulBookingModel.started && _elapsedTimer == null) {
        _startElapsedTick();
      }
      if (b.status == HaulBookingModel.completed) {
        _sub?.cancel();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) => HaulCompleteScreen(booking: b)),
            (r) => r.isFirst,
          );
        }
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

  Future<void> _callOwner() async {
    final phone = _booking?.ownerPhone ?? '';
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _cancelBooking() async {
    String? reason;
    const reasons = [
      'Found another vehicle',
      'Plan changed',
      'Waiting too long',
      'Wrong village selected',
      'Other',
    ];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Cancel Booking',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 4),
              const Text('Why are you cancelling?',
                  style: TextStyle(
                      color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 16),
              ...reasons.map((r) => GestureDetector(
                onTap: () => set(() => reason = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: reason == r
                        ? AppColors.bgOrange : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: reason == r
                            ? AppColors.primaryOrange
                            : Colors.grey[200]!),
                  ),
                  child: Row(children: [
                    Icon(
                      reason == r
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: reason == r
                          ? AppColors.primaryOrange
                          : AppColors.textGrey,
                      size: 18),
                    const SizedBox(width: 10),
                    Text(r,
                        style: TextStyle(
                            fontWeight: reason == r
                                ? FontWeight.bold : FontWeight.normal,
                            color: reason == r
                                ? AppColors.primaryOrange
                                : AppColors.textDark)),
                  ]),
                ),
              )),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Booking',
                      style: TextStyle(color: AppColors.textDark)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: reason != null
                      ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      await HaulService.cancelBooking(
          widget.bookingId, reason ?? 'Cancelled by customer');
      if (mounted) Navigator.pop(context);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final isSearching = b == null || b.status == HaulBookingModel.searching;
    final isAccepted  = b?.status == HaulBookingModel.accepted;
    final isStarted   = b?.status == HaulBookingModel.started;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('GaamHaul Rental',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: isSearching
            ? BackButton(
                color: Colors.white, onPressed: _cancelBooking)
            : const BackButton(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SosButton(
                lat: b?.pickupLat, lng: b?.pickupLng),
          ),
        ],
      ),
      body: b == null
          ? _buildSearching()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Status stepper
                _buildStepper(b.status),

                const SizedBox(height: 16),

                // Vehicle + owner card
                _buildVehicleOwnerCard(b),

                const SizedBox(height: 14),

                // Booking details card
                _buildDetailsCard(b),

                if (isStarted) ...[
                  const SizedBox(height: 14),
                  _buildElapsedTimer(b),
                ],

                if (isSearching) ...[
                  const SizedBox(height: 14),
                  _buildSearchingCard(),
                ],

                if (isAccepted) ...[
                  const SizedBox(height: 14),
                  _buildOwnerComingCard(b),
                ],

                const SizedBox(height: 24),

                if (isSearching)
                  TextButton.icon(
                    onPressed: _cancelBooking,
                    icon: const Icon(Icons.cancel_outlined,
                        color: AppColors.error, size: 16),
                    label: const Text('Cancel Booking',
                        style: TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ),
              ]),
            ),
    );
  }

  Widget _buildSearching() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🚛', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 20),
        const Text('Finding your vehicle owner…',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const LinearProgressIndicator(
          color: AppColors.primaryOrange,
          backgroundColor: AppColors.bgOrange,
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _cancelBooking,
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.error)),
        ),
      ]),
    );
  }

  Widget _buildStepper(String status) {
    final stages = [
      {'id': HaulBookingModel.searching, 'label': 'Finding', 'icon': '🔍'},
      {'id': HaulBookingModel.accepted,  'label': 'Confirmed', 'icon': '✅'},
      {'id': HaulBookingModel.started,   'label': 'Working', 'icon': '🚛'},
      {'id': HaulBookingModel.completed, 'label': 'Done', 'icon': '✓'},
    ];
    final order = [
      HaulBookingModel.searching,
      HaulBookingModel.accepted,
      HaulBookingModel.started,
      HaulBookingModel.completed,
    ];
    final currentIdx = order.indexOf(status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)
        ],
      ),
      child: Row(children: List.generate(stages.length, (i) {
        final done   = i < currentIdx;
        final active = i == currentIdx;
        return Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: done || active
                        ? AppColors.primaryOrange
                        : Colors.grey.shade200,
                  ),
                ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.primaryOrange
                      : active
                          ? AppColors.bgOrange
                          : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: active
                          ? AppColors.primaryOrange
                          : Colors.transparent,
                      width: 2),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 16)
                      : Text(stages[i]['icon'] as String,
                          style: const TextStyle(fontSize: 14)),
                ),
              ),
              if (i < stages.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: done
                        ? AppColors.primaryOrange
                        : Colors.grey.shade200,
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(stages[i]['label'] as String,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active
                        ? FontWeight.bold : FontWeight.normal,
                    color: active
                        ? AppColors.primaryOrange
                        : done
                            ? AppColors.primaryOrange
                            : AppColors.textGrey)),
          ]),
        );
      })),
    );
  }

  Widget _buildVehicleOwnerCard(HaulBookingModel b) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)
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
                        fontWeight: FontWeight.bold, fontSize: 16)),
                if (b.vehicleNumber.isNotEmpty)
                  Text(b.vehicleNumber,
                      style: const TextStyle(
                          color: AppColors.textGrey, fontSize: 12)),
              ],
            ),
          ),
        ]),
        if (b.ownerName.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.bgOrange,
              child: Text(
                b.ownerName[0].toUpperCase(),
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
                  Text(b.ownerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const Text('Vehicle Owner',
                      style: TextStyle(
                          color: AppColors.textGrey, fontSize: 11)),
                ],
              ),
            ),
            if (b.status != HaulBookingModel.searching)
              IconButton(
                onPressed: _callOwner,
                icon: const Icon(Icons.call, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(10),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildDetailsCard(HaulBookingModel b) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)
        ],
      ),
      child: Column(children: [
        _detailRow(Icons.location_on_outlined, 'Pickup Village',
            b.pickupVillage),
        const Divider(height: 20),
        _detailRow(Icons.inventory_2_outlined, 'Load',
            b.loadDescription.isNotEmpty ? b.loadDescription : '—'),
        const Divider(height: 20),
        _detailRow(Icons.timer_outlined, 'Duration', b.durationLabel),
        if (b.ratePerHour > 0) ...[
          const Divider(height: 20),
          _detailRow(Icons.currency_rupee, 'Rate',
              '₹${b.ratePerHour.toStringAsFixed(0)} / hour'),
        ],
        const Divider(height: 20),
        _detailRow(Icons.receipt_outlined, 'Total Rental',
            '₹${b.ownerEarnings.toStringAsFixed(0)}',
            bold: true, color: AppColors.primaryOrange),
      ]),
    );
  }

  Widget _buildElapsedTimer(HaulBookingModel b) {
    final elapsed  = b.elapsed;
    final fraction = b.elapsedFraction;
    final isOver   = fraction >= 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOver
              ? [Colors.red.shade700, Colors.red.shade400]
              : [const Color(0xFFE65100), const Color(0xFFF57C00)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Text(
          isOver ? '⚠️ Time Exceeded' : '⏱ Work in Progress',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          _formatDuration(elapsed),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text('Booked: ${b.durationLabel}',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.white.withAlpha(60),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(fraction * 100).toInt().clamp(0, 999)}% of booked time used',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ]),
    );
  }

  Widget _buildSearchingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgOrange,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.primaryOrange.withAlpha(80)),
      ),
      child: const Row(children: [
        SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primaryOrange,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Waiting for owner to accept your booking…\n'
            'This usually takes 1–3 minutes.',
            style: TextStyle(
                color: AppColors.primaryOrange, fontSize: 13),
          ),
        ),
      ]),
    );
  }

  Widget _buildOwnerComingCard(HaulBookingModel b) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(children: [
        Text(b.vehicleEmoji,
            style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Owner is on the way!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 14)),
              Text(
                '${b.ownerName} is heading to ${b.pickupVillage}',
                style: const TextStyle(
                    color: Colors.blue, fontSize: 12),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {bool bold = false, Color? color}) {
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
}

