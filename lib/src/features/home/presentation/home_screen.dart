import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SECURETRACE AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('My Devices', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildDeviceCard('Primary Device', 'Online • Target Tracking Active', Icons.smartphone, true),
          const SizedBox(height: 16),
          _buildDeviceCard('Child Android', 'Offline • Battery 12%', Icons.phone_android, false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => _buildLinkDeviceOptions(context),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Link Device'),
      ),
    );
  }

  Widget _buildDeviceCard(String name, String status, IconData icon, bool isOnline) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF00E5FF).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isOnline ? const Color(0xFF00E5FF) : Colors.grey, size: 28),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(status, style: TextStyle(color: isOnline ? Colors.white70 : Colors.grey)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to device details
        },
      ),
    );
  }

  Widget _buildLinkDeviceOptions(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Link a New Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF00E5FF)),
            title: const Text('Scan QR Code'),
            subtitle: const Text('Track this device from the parent phone'),
            onTap: () {
              Navigator.pop(context);
              context.push('/connect/scan');
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code, color: Color(0xFF00E5FF)),
            title: const Text('Show QR Code'),
            subtitle: const Text('Let the tracking phone scan this device'),
            onTap: () {
              Navigator.pop(context);
              context.push('/connect/generate');
            },
          ),
        ],
      ),
    );
  }
}
