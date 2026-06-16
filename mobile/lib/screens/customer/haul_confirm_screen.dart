import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/village_model.dart';
import '../../models/haul_vehicle_model.dart';
import '../../services/haul_service.dart';
import '../../utils/fare_calculator.dart';
import 'haul_tracking_screen.dart';

class HaulConfirmScreen extends StatefulWidget {
  final HaulVehicleModel vehicle;
  final VillageModel pickupVillage;
  final String duration;
  final String loadDescription;
  final String customerId;
  final String customerName;
  final String customerPhone;

  const HaulConfirmScreen({
    super.key,
    required this.vehicle,
    required this.pickupVillage,
    required this.duration,
    required this.loadDescription,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  State<HaulConfirmScreen> createState() => _HaulConfirmScreenState();
}

class _HaulConfirmScreenState extends State<HaulConfirmScreen> {
  bool _loading = false;

  double get _ownerEarnings =>
      FareCalculator.ownerEarnings(widget.vehicle.ratePerHour.toInt(), widget.duration);

  String get _durationLabel {
    const labels = {
      '1h': '1 Hour', '2h': '2 Hours',
      'half_day': 'Half Day (4h)', 'full_day': 'Full Day (8h)',
    };
    return labels[widget.duration] ?? widget.duration;
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    final bookingId = await HaulService.createBooking(
      customerId: widget.customerId,
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      vehicleOwnerId: widget.vehicle.uid,
      ownerName: widget.vehicle.ownerName,
      ownerPhone: widget.vehicle.phone,
      vehicleType: widget.vehicle.vehicleType,
      vehicleNumber: widget.vehicle.vehicleNumber,
      duration: widget.duration,
      durationHours: _ownerEarnings / widget.vehicle.ratePerHour,
      loadDescription: widget.loadDescription,
      pickupVillage: widget.pickupVillage.name,
      pickupLat: widget.pickupVillage.lat,
      pickupLng: widget.pickupVillage.lng,
      ratePerHour: widget.vehicle.ratePerHour,
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HaulTrackingScreen(bookingId: bookingId)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Confirm Haul Booking',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _Row('Vehicle', widget.vehicle.vehicleTypeLabel),
                  _Row('Owner', widget.vehicle.ownerName),
                  _Row('Pickup', '${widget.pickupVillage.nameGu} · ${widget.pickupVillage.name}'),
                  _Row('Duration', _durationLabel),
                  if (widget.loadDescription.isNotEmpty)
                    _Row('Load', widget.loadDescription),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('App Commission (fixed)',
                          style: TextStyle(color: AppColors.primaryOrange)),
                      const Text('₹75',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Owner Earnings',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '₹${_ownerEarnings.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Payment info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text(
                    'ચુકવણી માહિતી / Payment Info',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  )),
                ]),
                const SizedBox(height: 10),
                _InfoRow('App fee ₹75', 'Booking confirm થયા પછી ₹75 charged'),
                _InfoRow('Owner earnings', 'સીધા owner ને cash/UPI આપો'),
                _InfoRow('Cash / UPI', 'Both payment methods accepted'),
              ]),
            ),
            const SizedBox(height: 10),
            // Cancellation policy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.cancel_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Expanded(child: Text(
                  'Booking confirm પહેલાં cancel free. '
                  'પછી ₹20 cancellation charge.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loading ? null : _confirm,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirm Booking',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  TextSpan(text: '$label — ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
