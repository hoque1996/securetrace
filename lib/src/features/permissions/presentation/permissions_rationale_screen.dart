import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/services.dart';

class PermissionsRationaleScreen extends StatefulWidget {
  const PermissionsRationaleScreen({super.key});

  @override
  State<PermissionsRationaleScreen> createState() => _PermissionsRationaleScreenState();
}

class _PermissionsRationaleScreenState extends State<PermissionsRationaleScreen> {
  bool _notificationsGranted = false;
  bool _locationGranted = false;
  bool _batteryIgnored = false;
  bool _phoneStateGranted = false;
  bool _deviceAdminGranted = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    _notificationsGranted = await Permission.notification.isGranted;
    _locationGranted = await Permission.locationAlways.isGranted;
    _batteryIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
    _phoneStateGranted = await Permission.phone.isGranted;
    
    try {
      const platform = MethodChannel('com.example.secure_trace/device_admin');
      _deviceAdminGranted = await platform.invokeMethod('isAdminActive') ?? false;
    } catch (e) {
      _deviceAdminGranted = false;
    }

    setState(() {});
  }

  Future<void> _requestPermissions() async {
    if (!_notificationsGranted) {
      await Permission.notification.request();
    }
    if (!_locationGranted) {
      var locStatus = await Permission.location.request();
      if (locStatus.isGranted) {
        await Permission.locationAlways.request();
      }
    }
    if (!_batteryIgnored) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    if (!_phoneStateGranted) {
      await Permission.phone.request();
    }
    await _checkStatus();
    
    if (_notificationsGranted && _locationGranted && _batteryIgnored && _phoneStateGranted) {
      FlutterBackgroundService().startService();
      if (mounted) context.go('/devices');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETUP SECURETRACE'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Required Permissions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'To ensure SecureTrace AI can protect this device and track it when lost, we need the following permissions. We do NOT share this data with third parties.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            _buildPermissionItem(
              icon: Icons.notifications_active,
              title: 'Persistent Notifications',
              description: 'Required to keep the tracking service alive and notify you of security events.',
              isGranted: _notificationsGranted,
            ),
            const SizedBox(height: 20),
            _buildPermissionItem(
              icon: Icons.sim_card_alert,
              title: 'Phone State (SIM Tracking)',
              description: 'Allows detection of unauthorized SIM card changes to alert you instantly.',
              isGranted: _phoneStateGranted,
            ),
            const SizedBox(height: 20),
            _buildPermissionItem(
              icon: Icons.location_on,
              title: 'Background Location',
              description: 'Allows tracking the device even when the app is closed. Select "Allow all the time".',
              isGranted: _locationGranted,
            ),
            const SizedBox(height: 20),
            _buildPermissionItem(
              icon: Icons.battery_charging_full,
              title: 'Ignore Battery Optimization',
              description: 'CRITICAL: Prevents Android from killing the tracking service after 10 minutes.',
              isGranted: _batteryIgnored,
            ),
            const SizedBox(height: 20),
            // Device Admin explicit intent trigger
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 32, color: _deviceAdminGranted ? Colors.green : Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Device Administrator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Allows remote lock protection.', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      if (!_deviceAdminGranted)
                        OutlinedButton(
                          onPressed: () async {
                            const platform = MethodChannel('com.example.secure_trace/device_admin');
                            await platform.invokeMethod('requestAdmin');
                            // Delaying to give Android time to return back from the global settings intent
                            await Future.delayed(const Duration(seconds: 3));
                            await _checkStatus();
                          },
                          child: const Text('Enable Lock Security'),
                        ),
                    ],
                  ),
                ),
                if (_deviceAdminGranted) const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('Grant Permissions'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => context.go('/devices'),
                child: const Text('Skip for now (Features will be limited)', style: TextStyle(color: Colors.grey)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem({required IconData icon, required String title, required String description, required bool isGranted}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 32, color: isGranted ? Colors.green : Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        if (isGranted) const Icon(Icons.check_circle, color: Colors.green),
      ],
    );
  }
}
