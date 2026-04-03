import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notifications_active),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.security),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.map),
            label: 'Tracking',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_remote),
            label: 'Control',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_circle),
            label: 'Vault',
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
