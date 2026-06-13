import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../services/ride_service.dart';
import '../../widgets/earnings_card.dart';

class _Badge {
  final String title;
  final String titleGu;
  final String description;
  final IconData icon;
  final Color color;
  final int requiredRides;

  const _Badge({
    required this.title,
    required this.titleGu,
    required this.description,
    required this.icon,
    required this.color,
    required this.requiredRides,
  });
}

const _badges = [
  _Badge(
    title: 'Bronze Saathi',
    titleGu: 'કાંસ્ય સાથી',
    description: '10+ rides completed',
    icon: Icons.emoji_events_outlined,
    color: Color(0xFFCD7F32),
    requiredRides: 10,
  ),
  _Badge(
    title: 'Silver Saathi',
    titleGu: 'ચાંદી સાથી',
    description: '50+ rides completed',
    icon: Icons.emoji_events,
    color: Color(0xFF9E9E9E),
    requiredRides: 50,
  ),
  _Badge(
    title: 'Gold Saathi',
    titleGu: 'સોના સાથી',
    description: '100+ rides completed',
    icon: Icons.emoji_events,
    color: Color(0xFFFFC107),
    requiredRides: 100,
  ),
  _Badge(
    title: 'Diamond Saathi',
    titleGu: 'હીરા સાથી',
    description: '500+ rides completed',
    icon: Icons.diamond,
    color: Color(0xFF29B6F6),
    requiredRides: 500,
  ),
];

class SaathiEarningsScreen extends StatefulWidget {
  const SaathiEarningsScreen({super.key});

  @override
  State<SaathiEarningsScreen> createState() => _SaathiEarningsScreenState();
}

class _SaathiEarningsScreenState extends State<SaathiEarningsScreen> {
  Map<String, dynamic> _earnings = {};
  int _totalRides = 0;
  double _rating = 5.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final results = await Future.wait([
      RideService.getSaathiEarnings(uid),
      FirebaseFirestore.instance.collection('saathis').doc(uid).get(),
    ]);
    final earnings = results[0] as Map<String, dynamic>;
    final saathiSnap = results[1] as DocumentSnapshot;
    final saathiData =
        saathiSnap.exists ? saathiSnap.data() as Map<String, dynamic> : {};
    if (mounted) {
      setState(() {
        _earnings = earnings;
        _totalRides = (saathiData['totalRides'] ??
            earnings['totalRides'] ??
            0).toInt();
        _rating = (saathiData['rating'] ?? 5.0).toDouble();
        _loading = false;
      });
    }
  }

  _Badge? get _currentBadge {
    _Badge? best;
    for (final b in _badges) {
      if (_totalRides >= b.requiredRides) best = b;
    }
    return best;
  }

  _Badge? get _nextBadge {
    for (final b in _badges) {
      if (_totalRides < b.requiredRides) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Earnings',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: EarningsCard(
                          label: "Today",
                          amount: (_earnings['today'] ?? 0).toDouble(),
                          rides: (_earnings['todayRides'] ?? 0).toInt(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EarningsCard(
                          label: 'This Week',
                          amount: (_earnings['week'] ?? 0).toDouble(),
                          color: AppColors.lightGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  EarningsCard(
                    label: 'This Month',
                    amount: (_earnings['month'] ?? 0).toDouble(),
                    rides: (_earnings['totalRides'] ?? 0).toInt(),
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 20),

                  _BadgeSection(
                    totalRides: _totalRides,
                    rating: _rating,
                    currentBadge: _currentBadge,
                    nextBadge: _nextBadge,
                  ),

                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Payment Info',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const _PayRow('App Commission', '0% (no cut for now)'),
                        const _PayRow('You Keep', '100% of fare'),
                        const _PayRow('Payment Mode', 'Cash from customer'),
                        _PayRow(
                          'Your Rating',
                          '${_rating.toStringAsFixed(1)} ★  ($_totalRides rides)',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  final int totalRides;
  final double rating;
  final _Badge? currentBadge;
  final _Badge? nextBadge;

  const _BadgeSection({
    required this.totalRides,
    required this.rating,
    required this.currentBadge,
    required this.nextBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.military_tech, color: AppColors.primaryGreen, size: 20),
              SizedBox(width: 6),
              Text('Saathi Level',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),

          if (currentBadge != null) ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: currentBadge!.color.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(currentBadge!.icon,
                          color: currentBadge!.color, size: 36),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentBadge!.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: currentBadge!.color),
                  ),
                  Text(
                    currentBadge!.titleGu,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_outlined,
                        color: Colors.grey, size: 30),
                  ),
                  const SizedBox(height: 8),
                  const Text('No badge yet',
                      style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (nextBadge != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.arrow_upward, color: nextBadge!.color, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Next: ${nextBadge!.title}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: nextBadge!.color),
                ),
                const Spacer(),
                Text(
                  '${totalRides}/${nextBadge!.requiredRides} rides',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (totalRides / nextBadge!.requiredRides).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(nextBadge!.color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${nextBadge!.requiredRides - totalRides} more rides to go!',
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text('All Badges', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _badges.map((b) {
              final unlocked = totalRides >= b.requiredRides;
              return Tooltip(
                message: b.description,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: unlocked ? b.color.withAlpha(30) : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        b.icon,
                        color: unlocked ? b.color : Colors.grey[400],
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.title.split(' ').first,
                      style: TextStyle(
                          fontSize: 9,
                          color: unlocked ? b.color : Colors.grey[400],
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;

  const _PayRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
