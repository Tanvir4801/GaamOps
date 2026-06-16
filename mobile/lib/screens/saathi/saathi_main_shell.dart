import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'saathi_dashboard.dart';
import 'saathi_earnings_screen.dart';
import 'saathi_history_screen.dart';
import 'saathi_profile_screen.dart';

class SaathiMainShell extends StatefulWidget {
  const SaathiMainShell({super.key});

  @override
  State<SaathiMainShell> createState() => _SaathiMainShellState();
}

class _SaathiMainShellState extends State<SaathiMainShell> {
  int _currentIndex = 0;

  final _screens = const [
    SaathiDashboard(),
    SaathiEarningsScreen(),
    SaathiHistoryScreen(),
    SaathiProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.bgGreen,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primaryGreen),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.primaryGreen),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}