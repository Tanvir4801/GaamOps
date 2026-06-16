import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'haul_owner_dashboard.dart';
import 'haul_owner_history_screen.dart';
import 'haul_owner_profile_screen.dart';

class HaulOwnerShell extends StatefulWidget {
  const HaulOwnerShell({super.key});

  @override
  State<HaulOwnerShell> createState() => _HaulOwnerShellState();
}

class _HaulOwnerShellState extends State<HaulOwnerShell> {
  int _index = 0;

  final _screens = const [
    HaulOwnerDashboard(),
    HaulOwnerHistoryScreen(),
    HaulOwnerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.bgOrange,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping,
                color: AppColors.primaryOrange),
            label: 'Jobs',
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
