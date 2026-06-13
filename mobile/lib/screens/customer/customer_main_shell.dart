import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'customer_home_screen.dart';
import 'ride_history_screen.dart';
import 'customer_profile_screen.dart';
import 'gaam_haul_home_screen.dart';

class CustomerMainShell extends StatefulWidget {
  const CustomerMainShell({super.key});

  @override
  State<CustomerMainShell> createState() => _CustomerMainShellState();
}

class _CustomerMainShellState extends State<CustomerMainShell> {
  int _currentIndex = 0;

  final _screens = const [
    CustomerHomeScreen(),
    GaamHaulHomeScreen(),
    RideHistoryScreen(),
    CustomerProfileScreen(),
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
            icon: Icon(Icons.electric_rickshaw_outlined),
            selectedIcon: Icon(Icons.electric_rickshaw, color: AppColors.primaryGreen),
            label: 'GaamRide',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping, color: AppColors.primaryOrange),
            label: 'GaamHaul',
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
