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
  bool _hasError = false;
  late AnimationController _balanceCtrl;
  late Animation<double> _balanceAnim;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _balanceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _balanceAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _balanceCtrl, curve: Curves.easeOutCubic),
    );
    _load();
  }

  Future<void> _load() async {
    if (_uid.isEmpty) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
      return;
    }

    setState(() { _loading = true; _hasError = false; });

    try {
      double balance = 0;
      List<Map<String, dynamic>> transactions = [];

      // Primary path: users/{uid}/wallet/balance document
      final walletDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('wallet')
          .doc('balance')
          .get();

      if (walletDoc.exists && walletDoc.data() != null) {
        balance = (walletDoc.data()!['balance'] ?? 0).toDouble();

        // Transactions subcollection
        try {
          final txnSnap = await walletDoc.reference
              .collection('transactions')
              .orderBy('createdAt', descending: true)
              .limit(30)
              .get();
          transactions = txnSnap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
        } catch (_) {}
      } else {
        // Fallback: check gaamCash field on user document
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .get();
        if (userDoc.exists) {
          balance = (userDoc.data()?['gaamCash'] ?? 0).toDouble();
        }

        // Initialize wallet doc so it exists for next time
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('wallet')
            .doc('balance')
            .set({
          'balance': balance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        _balanceAnim = Tween<double>(begin: 0, end: balance).animate(
          CurvedAnimation(parent: _balanceCtrl, curve: Curves.easeOutCubic),
        );
        _balanceCtrl.forward(from: 0);
        setState(() {
          _balance = balance;
          _transactions = transactions;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Wallet load error: $e');
      if (mounted) {
        setState(() { _loading = false; _hasError = true; });
      }
    }
  }

  Color _txnColor(String? type) {
    if (type == 'cashback' || type == 'credit' || type == 'referral' || type == 'bonus') {
      return AppColors.primaryGreen;
    }
    return Colors.red;
  }

  IconData _txnIcon(String? type) {
    switch (type) {
      case 'cashback': return Icons.percent_rounded;
      case 'referral': return Icons.people_outline;
      case 'credit': return Icons.add_circle_outline;
      case 'bonus': return Icons.card_giftcard_outlined;
      case 'rating': return Icons.star_outline;
      default: return Icons.remove_circle_outline;
    }
  }

  String _txnLabel(String? type) {
    switch (type) {
      case 'cashback': return 'Ride Cashback';
      case 'referral': return 'Referral Bonus';
      case 'credit': return 'Credit Added';
      case 'bonus': return 'Bonus Reward';
      case 'rating': return 'Rating Reward';
      default: return 'Ride Payment';
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
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textDark),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _hasError
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primaryGreen,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _BalanceCard(
                            animation: _balanceAnim, balance: _balance),
                        const SizedBox(height: 16),
                        _QuickStatsRow(transactions: _transactions),
                        const SizedBox(height: 16),
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
                                type == 'credit' ||
                                type == 'bonus' ||
                                type == 'rating';
                            final ts = txn['createdAt'];
                            String dateStr = '';
                            if (ts != null && ts is Timestamp) {
                              final d = ts.toDate();
                              dateStr =
                                  '${d.day}/${d.month}/${d.year}';
                            }
                            return _TransactionTile(
                              icon: _txnIcon(type),
                              label: _txnLabel(type),
                              note: txn['note'] as String? ?? dateStr,
                              amount: amount,
                              isCredit: isCredit,
                              color: _txnColor(type),
                              index: i,
                            );
                          }),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.red.shade300, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Wallet load failed',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              'Could not load your GaamCash balance.\nPlease retry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Animation<double> animation;
  final double balance;
  const _BalanceCard({required this.animation, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), AppColors.primaryGreen],
        ),
        borderRadius: BorderRadius.circular(24),
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
              Text('GaamCash Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Text(
              '₹${animation.value.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 13),
                    SizedBox(width: 5),
                    Text('Earns 2% cashback per ride',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 11)),
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

class _QuickStatsRow extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  const _QuickStatsRow({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final credits = transactions.where((t) {
      final type = t['type'] as String?;
      return type == 'cashback' ||
          type == 'referral' ||
          type == 'credit' ||
          type == 'bonus' ||
          type == 'rating';
    }).fold(0.0, (s, t) => s + (t['amount'] ?? 0).toDouble());

    final debits = transactions.where((t) {
      final type = t['type'] as String?;
      return type == 'debit' || type == 'payment';
    }).fold(0.0, (s, t) => s + (t['amount'] ?? 0).toDouble());

    return Row(
      children: [
        _statChip(Icons.arrow_downward_rounded, 'Earned',
            '₹${credits.toStringAsFixed(0)}', AppColors.primaryGreen),
        const SizedBox(width: 10),
        _statChip(Icons.arrow_upward_rounded, 'Used',
            '₹${debits.toStringAsFixed(0)}', Colors.orange.shade700),
        const SizedBox(width: 10),
        _statChip(
            Icons.receipt_long_outlined,
            'Transactions',
            '${transactions.length}',
            Colors.blue.shade600),
      ],
    );
  }

  Widget _statChip(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}

class _HowToEarnCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.directions_bike, 'Complete a ride', 'Earn 2% of fare as GaamCash'),
      (Icons.people_outlined, 'Refer a friend',
          'Get ₹20 when they book first ride'),
      (Icons.star_outline, 'Rate your Saathi', 'Earn ₹2 cashback for rating'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
              SizedBox(width: 6),
              Text('How to Earn GaamCash',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.$1,
                        color: AppColors.primaryGreen, size: 16),
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
            ),
          ),
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
      duration: Duration(milliseconds: 300 + widget.index * 50),
    );
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.isCredit ? '+' : '-'}₹${widget.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: widget.color,
                    ),
                  ),
                  if (widget.isCredit)
                    Text('credited',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400))
                  else
                    Text('used',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400)),
                ],
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
            decoration: const BoxDecoration(
              color: AppColors.bgGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.primaryGreen, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No transactions yet',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
