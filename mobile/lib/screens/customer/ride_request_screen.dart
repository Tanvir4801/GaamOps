import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/village_model.dart';
import '../../models/saathi_model.dart';
import '../../models/fare_breakdown.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';
import '../../services/village_service.dart';
import '../../services/fare_service.dart';
import 'ride_tracking_screen.dart';
import 'favourite_routes_screen.dart';
import 'payment_sheet.dart';

class RideRequestScreen extends StatefulWidget {
  final VillageModel pickupVillage;
  final VillageModel destinationVillage;
  final SaathiModel saathi;

  const RideRequestScreen({
    super.key,
    required this.pickupVillage,
    required this.destinationVillage,
    required this.saathi,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _fareLoading = true;
  FareBreakdown? _breakdown;
  final _promoCtrl = TextEditingController();
  bool _promoApplied = false;
  double _discount = 0;
  bool _breakdownExpanded = false;
  late AnimationController _btnCtrl;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
    )..value = 1.0;
    _loadFare();
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFare() async {
    final dist = VillageService.distanceBetween(
            widget.pickupVillage, widget.destinationVillage) /
        1000;
    final breakdown = await FareService.calculateFromFirestore(
      distanceKm: dist,
      rideTime: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _breakdown = breakdown;
        _fareLoading = false;
      });
    }
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
        _discount = validCodes[code]!;
        _promoApplied = true;
        _breakdown = _breakdown?.copyWithDiscount(_discount);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Promo applied — ₹${_discount.toStringAsFixed(0)} off!'),
        backgroundColor: AppColors.primaryGreen,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Invalid promo code'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _onConfirmTapped() async {
    if (_breakdown == null) return;
    _btnCtrl.reverse().then((_) => _btnCtrl.forward());

    final method = await showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentSheet(
        breakdown: _breakdown!,
        onConfirm: (m) => _submitRide(m),
      ),
    );

    if (method != null) await _submitRide(method);
  }

  Future<void> _submitRide(PaymentMethod method) async {
    if (_loading) return;
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = await AuthService.getUser(uid);
    final b = _breakdown!;
    final dist = VillageService.distanceBetween(
        widget.pickupVillage, widget.destinationVillage);

    FavouriteRoutesScreen.saveRoute(
      pickupVillage: widget.pickupVillage.name,
      destinationVillage: widget.destinationVillage.name,
      estimatedFare: b.totalFare,
    );

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
      fare: b.totalFare,
      distance: dist / 1000,
      paymentMethod:
          method == PaymentMethod.upi ? RideModel.paymentUpi : RideModel.paymentCash,
      baseFare: b.baseFare,
      distanceCharge: b.distanceCharge,
      surgeMultiplier: b.surgeMultiplier,
      lateNightFee: b.lateNightFee,
      gstAmount: b.gstAmount,
      platformFee: b.platformFee,
      promoDiscount: b.promoDiscount,
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
      body: _fareLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  SizedBox(height: 16),
                  Text('Calculating best fare…',
                      style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SaathiCard(saathi: widget.saathi),
                  const SizedBox(height: 12),
                  _RouteCard(
                    pickup: widget.pickupVillage,
                    destination: widget.destinationVillage,
                  ),
                  const SizedBox(height: 12),
                  if (_breakdown != null) ...[
                    _FareBreakdownCard(
                      breakdown: _breakdown!,
                      expanded: _breakdownExpanded,
                      onToggle: () => setState(
                          () => _breakdownExpanded = !_breakdownExpanded),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _PromoField(
                    controller: _promoCtrl,
                    applied: _promoApplied,
                    onApply: _applyPromo,
                    onClear: () {
                      setState(() {
                        _promoApplied = false;
                        _discount = 0;
                        _promoCtrl.clear();
                      });
                      _loadFare();
                    },
                  ),
                  const Spacer(),
                  if (_breakdown != null) ...[
                    _SurgeWarning(breakdown: _breakdown!),
                    const SizedBox(height: 8),
                  ],
                  ScaleTransition(
                    scale: _btnCtrl,
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
                        onPressed: _loading ? null : _onConfirmTapped,
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.payments_outlined,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Select Payment · ₹${_breakdown?.totalFare.toStringAsFixed(0) ?? '…'}',
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.bgGreen,
            child: Text(
              saathi.name.isNotEmpty ? saathi.name[0].toUpperCase() : 'S',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(saathi.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${saathi.vehicleType} · ${saathi.vehicleNumber}',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 3),
                Text(saathi.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
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
      padding: const EdgeInsets.all(14),
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
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textGrey)),
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
            child: Row(children: [
              Container(width: 2, height: 20, color: Colors.grey[300]),
            ]),
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
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textGrey)),
                    Text('${destination.nameGu} · ${destination.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
              Text(
                '${(VillageService.distanceBetween(pickup, destination) / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FareBreakdownCard extends StatelessWidget {
  final FareBreakdown breakdown;
  final bool expanded;
  final VoidCallback onToggle;

  const _FareBreakdownCard({
    required this.breakdown,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Fare',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      '₹${b.totalFare.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (b.isSurge)
                      _Badge('⚡ ${b.surgeLabel} ×${b.surgeMultiplier.toStringAsFixed(1)}',
                          Colors.orange),
                    if (b.isLateNight)
                      _Badge('🌙 Late Night +₹${b.lateNightFee.toStringAsFixed(0)}',
                          Colors.indigo),
                    if (b.promoDiscount > 0)
                      _Badge('🎉 -₹${b.promoDiscount.toStringAsFixed(0)} Promo',
                          Colors.green),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          expanded ? 'Hide details' : 'See breakdown',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                        Icon(
                          expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _BreakdownRow('Base fare', b.baseFare),
                    _BreakdownRow(
                        'Distance (${b.distanceKm.toStringAsFixed(1)} km × ₹${(b.distanceKm > 0 ? b.distanceCharge / b.distanceKm : 0).toStringAsFixed(0)}/km)',
                        b.distanceCharge),
                    if (b.isSurge)
                      _BreakdownRow(
                          'Surge ×${b.surgeMultiplier.toStringAsFixed(1)} (${b.surgeLabel})',
                          (b.subtotal / b.surgeMultiplier) *
                              (b.surgeMultiplier - 1),
                          color: Colors.orange.shade200),
                    if (b.isLateNight)
                      _BreakdownRow(
                          'Late night fee (11 PM–5 AM)', b.lateNightFee,
                          color: Colors.indigo.shade200),
                    _BreakdownRow(
                        'GST (${b.gstPercent.toStringAsFixed(0)}%)', b.gstAmount),
                    _BreakdownRow('Platform fee', b.platformFee),
                    if (b.promoDiscount > 0)
                      _BreakdownRow('Promo discount', -b.promoDiscount,
                          color: Colors.green.shade200),
                    const Divider(color: Colors.white24, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text('₹${b.totalFare.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color.withAlpha(230),
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  const _BreakdownRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          Text(
            value >= 0
                ? '+₹${value.toStringAsFixed(0)}'
                : '−₹${(-value).toStringAsFixed(0)}',
            style: TextStyle(
                color: color ?? Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 11),
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
          width: applied ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            applied ? Icons.local_offer : Icons.local_offer_outlined,
            color: applied ? AppColors.primaryGreen : AppColors.textGrey,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              readOnly: applied,
              decoration: InputDecoration(
                hintText: 'Promo code',
                hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
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
                  color: applied ? AppColors.primaryGreen : AppColors.textDark),
            ),
          ),
          GestureDetector(
            onTap: applied ? onClear : onApply,
            child: Text(
              applied ? 'Remove' : 'Apply',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: applied ? AppColors.error : AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurgeWarning extends StatelessWidget {
  final FareBreakdown breakdown;
  const _SurgeWarning({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    if (!breakdown.isSurge && !breakdown.isLateNight) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              breakdown.isLateNight
                  ? '🌙 Late night surcharge of ₹${breakdown.lateNightFee.toStringAsFixed(0)} applies (11 PM–5 AM)'
                  : '⚡ ${breakdown.surgeLabel} — ×${breakdown.surgeMultiplier.toStringAsFixed(1)} fare applies',
              style: const TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
