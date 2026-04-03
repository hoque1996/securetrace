import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/application/auth_controller.dart';
import '../../device_connect/application/device_connect_controller.dart';

class ControlPanelScreen extends ConsumerWidget {
  const ControlPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTROL PANEL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Security Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildActionCard(
            Icons.volume_up, 
            'Remote Ring', 
            'Force device to ring at max volume', 
            Colors.orange,
            () async {
              final targetId = ref.read(currentDeviceIdProvider);
              await FirebaseFirestore.instance
                .collection('devices')
                .doc(targetId)
                .collection('commands')
                .add({
                  'command': 'ring',
                  'status': 'pending',
                  'timestamp': FieldValue.serverTimestamp(),
                });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emergency Ring Command Sent!'), backgroundColor: Colors.orange),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.lock, 
            'Remote Lock', 
            'Lock device screen (Android only)', 
            Colors.red,
            () async {
              final targetId = ref.read(currentDeviceIdProvider);
              await FirebaseFirestore.instance
                .collection('devices')
                .doc(targetId)
                .collection('commands')
                .add({
                  'command': 'lock',
                  'status': 'pending',
                  'timestamp': FieldValue.serverTimestamp(),
                });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Remote Lock Command Sent!'), backgroundColor: Colors.red),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.camera_alt, 
            'Intruder Capture', 
            'Take photo on wrong PIN', 
            Colors.purple,
            () {},
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.videocam, 
            'Go Live (Broadcast)', 
            'Stream camera to linked devices', 
            Colors.orangeAccent,
            () => context.push('/cctv-broadcast'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.visibility, 
            'Remote View', 
            'Watch live feed from device', 
            Colors.purpleAccent,
            () => context.push('/cctv-view'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.biotech, 
            'AI Vision Monitor', 
            'Advanced object & human detection', 
            Colors.cyanAccent,
            () => context.push('/ai-vision'),
          ),
          const SizedBox(height: 32),
          const Text('Account & Compliance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            color: Colors.red.withValues(alpha: 0.1),
            child: ListTile(
               leading: const Icon(Icons.delete_forever, color: Colors.red),
               title: const Text('Delete Account & Data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
               subtitle: const Text('Permanently erase all tracking history and devices'),
               onTap: () async {
                 final confirm = await showDialog<bool>(
                   context: context,
                   builder: (ctx) => AlertDialog(
                     title: const Text('Delete Account?'),
                     content: const Text('This action is strictly irreversible. All tracking telemetry, registered devices, and your authentication profile will be permanently erased. Are you absolutely certain?'),
                     actions: [
                       TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                       TextButton(
                         onPressed: () => Navigator.of(ctx).pop(true), 
                         child: const Text('Delete Permanently', style: TextStyle(color: Colors.red))
                       ),
                     ],
                   ),
                 );
                 if (confirm == true) {
                   await ref.read(authControllerProvider.notifier).deleteAccount();
                 }
               }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15), 
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ),
        onTap: onTap,
      ),
    );
  }
}
