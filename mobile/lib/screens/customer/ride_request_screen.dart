import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/village_model.dart';
import '../../models/saathi_model.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';
import '../../services/village_service.dart';
import 'ride_tracking_screen.dart';
import 'favourite_routes_screen.dart';

class RideRequestScreen extends StatefulWidget {
  final VillageModel pickupVillage;
  final VillageModel destinationVillage;
  final SaathiModel saathi;
  final double fare;

  const RideRequestScreen({
    super.key,
    required this.pickupVillage,
    required this.destinationVillage,
    required this.saathi,
    required this.fare,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _savedFav = false;
  final _promoCtrl = TextEditingController();
  bool _promoApplied = false;
  double _discount = 0;
  late AnimationController _btnCtrl;
  late Animation<double> _btnScale;

  double get _finalFare => (widget.fare - _discount).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
    )..value = 1.0;
    _btnScale = _btnCtrl;
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  void _applyPromo() {
    final code = _promoCtrl.text.trim().toUpperCase();
    final validCodes = {
      'GAAM10': 10.0,
      'FIRSTRIDE': 20.0,
      'MAHUVA5': 5.0,
    };
    if (validCodes.containsKey(code)) {
      setState(() {
        _discount = validCodes[code]!.clamp(0, widget.fare);
        _promoApplied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Promo applied! ₹${_discount.toStringAsFixed(0)} off'),
        backgroundColor: AppColors.primaryGreen,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid promo code'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirm() async {
    _btnCtrl.reverse().then((_) => _btnCtrl.forward());
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = await AuthService.getUser(uid);
    final dist = VillageService.distanceBetween(
        widget.pickupVillage, widget.destinationVillage);

    if (!_savedFav) {
      FavouriteRoutesScreen.saveRoute(
        pickupVillage: widget.pickupVillage.name,
        destinationVillage: widget.destinationVillage.name,
        estimatedFare: _finalFare,
      );
      setState(() => _savedFav = true);
    }

    final rideId = await RideService.createRide(
      customerId: uid,
      customerName: user?.name ?? '',
      customerPhone: user?.phone ?? '',
      pickupVillage: widget.pickupVillage.name,
      pickupLat: widget.pickupVillage.lat,
      pickupLng: widget.pickupVillage.lng,
      destinationVillage: widget.destinationVillage.name,
      destinationLat: widget.destinationVillage.lat,
      destinationLng: widget.destinationVillage.lng,
      fare: _finalFare,
      distance: dist / 1000,
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => RideTrackingScreen(rideId: rideId)),
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
        title: const Text('Confirm Ride',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SaathiCard(saathi: widget.saathi),
            const SizedBox(height: 14),
            _RouteCard(
              pickup: widget.pickupVillage,
              destination: widget.destinationVillage,
            ),
            const SizedBox(height: 14),
            _PromoField(
              controller: _promoCtrl,
              applied: _promoApplied,
              onApply: _applyPromo,
              onClear: () => setState(() {
                _promoApplied = false;
                _discount = 0;
                _promoCtrl.clear();
              }),
            ),
            const SizedBox(height: 14),
            _FareCard(
              originalFare: widget.fare,
              discount: _discount,
              finalFare: _finalFare,
            ),
            const Spacer(),
            const _PaymentNote(),
            const SizedBox(height: 12),
            ScaleTransition(
              scale: _btnScale,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppColors.primaryGreen.withAlpha(80),
                  ),
                  onPressed: _loading ? null : _confirm,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Confirm & Book · ₹${_finalFare.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaathiCard extends StatelessWidget {
  final SaathiModel saathi;
  const _SaathiCard({required this.saathi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.bgGreen,
            child: Text(
              saathi.name.isNotEmpty ? saathi.name[0].toUpperCase() : 'S',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(saathi.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${saathi.vehicleType} · ${saathi.vehicleNumber}',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                const SizedBox(width: 3),
                Text(
                  saathi.rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final VillageModel pickup;
  final VillageModel destination;

  const _RouteCard({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: AppColors.primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pickup',
                        style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    Text('${pickup.nameGu} · ${pickup.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
            child: Row(
              children: [
                Container(width: 2, height: 20, color: Colors.grey[300]),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Drop-off',
                        style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    Text('${destination.nameGu} · ${destination.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoField extends StatelessWidget {
  final TextEditingController controller;
  final bool applied;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _PromoField({
    required this.controller,
    required this.applied,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: applied ? AppColors.primaryGreen : Colors.grey[200]!,
            width: applied ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(applied ? Icons.local_offer : Icons.local_offer_outlined,
              color: applied ? AppColors.primaryGreen : AppColors.textGrey,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              readOnly: applied,
              decoration: InputDecoration(
                hintText: 'Promo code (e.g. GAAM10)',
                hintStyle: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                suffixText: applied ? '✓ Applied' : null,
                suffixStyle: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color:
                      applied ? AppColors.primaryGreen : AppColors.textDark),
            ),
          ),
          GestureDetector(
            onTap: applied ? onClear : onApply,
            child: Text(
              applied ? 'Remove' : 'Apply',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color:
                      applied ? AppColors.error : AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _FareCard extends StatelessWidget {
  final double originalFare;
  final double discount;
  final double finalFare;

  const _FareCard({
    required this.originalFare,
    required this.discount,
    required this.finalFare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, Color(0xFF0E7C5B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryGreen.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fare to Pay',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              if (discount > 0)
                Text(
                  '₹${originalFare.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      decoration: TextDecoration.lineThrough),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${finalFare.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1),
              ),
              if (discount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '₹${discount.toStringAsFixed(0)} OFF',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentNote extends StatelessWidget {
  const _PaymentNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.money, color: AppColors.textGrey, size: 16),
        const SizedBox(width: 6),
        Text(
          'Pay in cash directly to your Saathi',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    );
  }
}
