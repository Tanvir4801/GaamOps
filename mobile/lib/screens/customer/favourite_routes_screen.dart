import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';

class FavouriteRoute {
  final String id;
  final String pickupVillage;
  final String destinationVillage;
  final double? estimatedFare;

  FavouriteRoute({
    required this.id,
    required this.pickupVillage,
    required this.destinationVillage,
    this.estimatedFare,
  });

  factory FavouriteRoute.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FavouriteRoute(
      id: doc.id,
      pickupVillage: d['pickupVillage'] ?? '',
      destinationVillage: d['destinationVillage'] ?? '',
      estimatedFare: (d['estimatedFare'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'pickupVillage': pickupVillage,
        'destinationVillage': destinationVillage,
        'estimatedFare': estimatedFare ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class FavouriteRoutesScreen extends StatefulWidget {
  const FavouriteRoutesScreen({super.key});

  @override
  State<FavouriteRoutesScreen> createState() => _FavouriteRoutesScreenState();
}

class _FavouriteRoutesScreenState extends State<FavouriteRoutesScreen> {
  List<FavouriteRoute> _routes = [];
  bool _loading = true;

  CollectionReference get _col {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favourites');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    if (mounted) {
      setState(() {
        _routes = snap.docs.map((d) => FavouriteRoute.fromDoc(d)).toList();
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    await _col.doc(id).delete();
    setState(() => _routes.removeWhere((r) => r.id == id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route removed from favourites')),
      );
    }
  }

  static Future<void> saveRoute({
    required String pickupVillage,
    required String destinationVillage,
    double? estimatedFare,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favourites');
    final existing = await col
        .where('pickupVillage', isEqualTo: pickupVillage)
        .where('destinationVillage', isEqualTo: destinationVillage)
        .get();
    if (existing.docs.isEmpty) {
      await col.add(FavouriteRoute(
        id: '',
        pickupVillage: pickupVillage,
        destinationVillage: destinationVillage,
        estimatedFare: estimatedFare,
      ).toMap());
    }
  }

  static Future<List<FavouriteRoute>> loadRoutes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favourites')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    return snap.docs.map((d) => FavouriteRoute.fromDoc(d)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Favourite Routes',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _routes.isEmpty
              ? _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RouteCard(
                    route: _routes[i],
                    onDelete: () => _delete(_routes[i].id),
                  ),
                ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final FavouriteRoute route;
  final VoidCallback onDelete;

  const _RouteCard({required this.route, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star_rounded,
                color: AppColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: AppColors.primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.pickupVillage,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 1,
                    height: 12,
                    color: Colors.grey[300],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 10, color: Colors.orange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        route.destinationVillage,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
                if ((route.estimatedFare ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '~₹${route.estimatedFare!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_border_rounded,
                color: AppColors.primaryGreen, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'No favourite routes yet',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Book a ride and tap ★ to save it here',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
