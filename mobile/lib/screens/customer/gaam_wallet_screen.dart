import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';

class GaamWalletScreen extends StatefulWidget {
  const GaamWalletScreen({super.key});

  @override
  State<GaamWalletScreen> createState() => _GaamWalletScreenState();
}

class _GaamWalletScreenState extends State<GaamWalletScreen>
    with SingleTickerProviderStateMixin {
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  late AnimationController _balanceCtrl;
  late Animation<double> _balanceAnim;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _balanceCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _balanceAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _balanceCtrl, curve: Curves.easeOutCubic),
    );
    _load();
  }

  Future<void> _load() async {
    if (_uid.isEmpty) return;
    final walletDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('wallet')
        .doc('balance')
        .get();

    final txnSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('wallet')
        .doc('balance')
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final balance = walletDoc.exists
        ? (walletDoc.data()!['balance'] ?? 0).toDouble()
        : 0.0;

    if (mounted) {
      _balanceAnim = Tween<double>(begin: 0, end: balance).animate(
        CurvedAnimation(parent: _balanceCtrl, curve: Curves.easeOutCubic),
      );
      _balanceCtrl.forward();
      setState(() {
        _balance = balance;
        _transactions = txnSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _loading = false;
      });
    }
  }

  Color _txnColor(String? type) {
    if (type == 'cashback' || type == 'credit' || type == 'referral') {
      return AppColors.primaryGreen;
    }
    return Colors.red;
  }

  IconData _txnIcon(String? type) {
    switch (type) {
      case 'cashback': return Icons.percent_rounded;
      case 'referral': return Icons.people_outline;
      case 'credit': return Icons.add_circle_outline;
      default: return Icons.remove_circle_outline;
    }
  }

  String _txnLabel(String? type) {
    switch (type) {
      case 'cashback': return 'Ride Cashback';
      case 'referral': return 'Referral Bonus';
      case 'credit': return 'Credit Added';
      default: return 'Deducted';
    }
  }

  @override
  void dispose() {
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('GaamCash Wallet',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _BalanceCard(animation: _balanceAnim),
                  const SizedBox(height: 20),
                  _HowToEarnCard(),
                  const SizedBox(height: 20),
                  if (_transactions.isEmpty)
                    _EmptyTransactions()
                  else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Transaction History',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_transactions.length, (i) {
                      final txn = _transactions[i];
                      final type = txn['type'] as String?;
                      final amount = (txn['amount'] ?? 0).toDouble();
                      final isCredit = type == 'cashback' ||
                          type == 'referral' ||
                          type == 'credit';
                      return _TransactionTile(
                        icon: _txnIcon(type),
                        label: _txnLabel(type),
                        note: txn['note'] as String? ?? '',
                        amount: amount,
                        isCredit: isCredit,
                        color: _txnColor(type),
                        index: i,
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Animation<double> animation;
  const _BalanceCard({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryGreen, Color(0xFF0E7C5B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white70, size: 18),
              SizedBox(width: 6),
              Text(
                'GaamCash Balance',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Text(
              '₹${animation.value.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 13),
                SizedBox(width: 5),
                Text(
                  'Earns 2% cashback on every ride',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToEarnCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.directions_bike, 'Complete a ride', 'Earn 2% of fare as GaamCash'),
      (Icons.people_outlined, 'Refer a friend', 'Get ₹20 when they book first ride'),
      (Icons.star_outline, 'Rate your Saathi', 'Earn ₹2 cashback for rating'),
    ];
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
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
              SizedBox(width: 6),
              Text('How to Earn GaamCash',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.$1, color: AppColors.primaryGreen, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(item.$3,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String note;
  final double amount;
  final bool isCredit;
  final Color color;
  final int index;

  const _TransactionTile({
    required this.icon,
    required this.label,
    required this.note,
    required this.amount,
    required this.isCredit,
    required this.color,
    required this.index,
  });

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + widget.index * 60),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4)
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (widget.note.isNotEmpty)
                      Text(widget.note,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Text(
                '${widget.isCredit ? '+' : '-'}₹${widget.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.primaryGreen, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No transactions yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          const Text(
            'Book your first ride to start\nearning GaamCash cashback!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
