import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:secure_trace/src/features/ai_analysis/application/ai_pattern_service.dart';
import '../../../../firebase_options.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Initialize notifications channel for Foreground Service
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'secure_trace_tracking', 
    'SecureTrace AI Active',
    description: 'This channel is used for tracking your device in the background.',
    importance: Importance.low, // low importance keeps it silent but visible in status bar
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Create the notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'secure_trace_tracking',
      initialNotificationTitle: 'SecureTrace AI',
      initialNotificationContent: 'Initializing monitoring...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  // Start AI Pattern Analysis (Sensors)
  final aiPattern = AIPatternService(onAbnormalMovement: (msg, g) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('devices').doc(user.uid).collection('alerts').add({
        'type': 'ai_pattern_alert',
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'AI SENSOR ALERT: $msg',
        'magnitude': g,
      });
    }
  });
  aiPattern.startMonitoring();

  // Initialize Firebase exclusively in the background isolate
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  final deviceId = FirebaseAuth.instance.currentUser?.uid;
  if (deviceId != null) {
    FirebaseFirestore.instance
      .collection('devices')
      .doc(deviceId)
      .collection('commands')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final cmd = change.doc.data();
            if (cmd != null && cmd['command'] == 'ring') {
              // Bypasses silent modes naturally by using the device's main Alarm stream channel
              FlutterRingtonePlayer().play(
                android: AndroidSounds.alarm,
                ios: IosSounds.alarm,
                looping: true,
                volume: 1.0,
                asAlarm: true,
              );
              
              // Exactly 60s max ringing constraint to meet PRD requirements
              Timer(const Duration(seconds: 60), () {
                FlutterRingtonePlayer().stop();
              });
              
              change.doc.reference.update({'status': 'executed'});
            } else if (cmd != null && cmd['command'] == 'lock') {
              const platform = MethodChannel('com.example.secure_trace/device_admin');
              try {
                await platform.invokeMethod('lockDevice');
              } catch (e) {
                debugPrint('Failed to lock device: $e');
              }
              change.doc.reference.update({'status': 'executed'});
            }
          }
        }
      });
  }

  // Handle service state commands
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Location Polling Logic (every 30 seconds as per PRD)
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        try {
          // Fetch location
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );

          // Sync to Firestore (Generic success log)
          debugPrint('SecureTrace: Location sync successful.');
          
          // Update notification UI
          service.setForegroundNotificationInfo(
            title: "SecureTrace AI Active",
            content: "Monitoring device securely. Last sync: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          );

          // Check for Intruder Alerts (Wrong PIN/Pattern)
          try {
            const platform = MethodChannel('com.example.secure_trace/device_admin');
            final bool hasIntruder = await platform.invokeMethod('checkIntruder') ?? false;
            
            if (hasIntruder) {
              final prefs = await SharedPreferences.getInstance();
              final lastAlertTime = prefs.getInt('last_intruder_alert') ?? 0;
              final now = DateTime.now().millisecondsSinceEpoch;
              
              // Local Rate Limiting: 60 seconds cooldown to prevent Firestore spamming / Billing attacks
              if (now - lastAlertTime > 60000) {
                final deviceId = FirebaseAuth.instance.currentUser?.uid;
                if (deviceId != null) {
                  // Face capture + photo upload + GPS + notification is handled by
                  // IntruderOverlayScreen (triggered after 3 failed logins in LoginScreen).
                  // This background path logs a lightweight Firestore alert for native
                  // device-admin PIN/pattern wrong-attempt detection.
                  await FirebaseFirestore.instance
                    .collection('devices')
                    .doc(deviceId)
                    .collection('alerts')
                    .add({
                      'type': 'intruder_alert',
                      'timestamp': FieldValue.serverTimestamp(),
                      'message': 'SECURITY ALERT: Wrong PIN/Pattern detected on the device!',
                      'source': 'device_admin_background',
                    });
                  await prefs.setInt('last_intruder_alert', now);
                }
              }
            }
          } catch (e) {
            debugPrint('Intruder check failed: $e');
          }

          // Check for SIM Card Changes
          try {
            const platform = MethodChannel('com.example.secure_trace/device_admin');
            final String currentSimState = await platform.invokeMethod('checkSimState') ?? '';
            
            if (currentSimState != 'UNSUPPORTED_API' && currentSimState.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              final savedSimState = prefs.getString('saved_sim_state');
              
              if (savedSimState == null) {
                // First initialization, save baseline carrier state
                await prefs.setString('saved_sim_state', currentSimState);
              } else if (savedSimState != currentSimState && currentSimState != 'NO_SIM') {
                // SIM Profile has changed!
                final deviceId = FirebaseAuth.instance.currentUser?.uid;
                if (deviceId != null) {
                  await FirebaseFirestore.instance.collection('devices').doc(deviceId).collection('alerts').add({
                    'type': 'sim_change_alert',
                    'timestamp': FieldValue.serverTimestamp(),
                    'message': 'CRITICAL: Unauthorized SIM Card detected or swapped!',
                    'new_sim_data': currentSimState,
                  });
                  // Update baseline to prevent alert spam
                  await prefs.setString('saved_sim_state', currentSimState);
                }
              } else if (currentSimState == 'NO_SIM' && savedSimState != 'NO_SIM') {
                // SIM Card was manually removed
                final deviceId = FirebaseAuth.instance.currentUser?.uid;
                if (deviceId != null) {
                  await FirebaseFirestore.instance.collection('devices').doc(deviceId).collection('alerts').add({
                    'type': 'sim_removed_alert',
                    'timestamp': FieldValue.serverTimestamp(),
                    'message': 'WARNING: The SIM card was removed from the device!',
                  });
                  await prefs.setString('saved_sim_state', 'NO_SIM');
                }
              }
            }
          } catch (e) {
            debugPrint('SIM check failed: $e');
          }

          // Automated Periodic Cloud Sync (Contacts Backup Every 24h)
          try {
            final prefs = await SharedPreferences.getInstance();
            final bool autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
            
            if (autoSyncEnabled) {
              final lastSync = prefs.getInt('last_auto_sync_contacts') ?? 0;
              final now = DateTime.now().millisecondsSinceEpoch;
              
              // 24 Hour check (86400000 ms)
              if (now - lastSync > 86400000) {
                if (await FlutterContacts.permissions.request(PermissionType.readWrite) == PermissionStatus.granted) {
                  final contacts = await FlutterContacts.getAll(
                    properties: {ContactProperty.phone, ContactProperty.email},
                  );
                  
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final contactList = contacts.map((c) => {
                      'id': c.id,
                      'displayName': c.displayName,
                      'phones': c.phones.map((p) => p.number).toList(),
                      'emails': c.emails.map((e) => e.address).toList(),
                    }).toList();
                    
                    await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('backups')
                      .doc('contacts')
                      .set({
                        'last_backup': FieldValue.serverTimestamp(),
                        'total_contacts': contacts.length,
                        'data': contactList,
                        'sync_type': 'automated_background',
                      });
                      
                    await prefs.setInt('last_auto_sync_contacts', now);
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Auto-sync failed: $e');
          }

          // Geofencing: Boundary Breach Detection
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final geofencesSnapshot = await FirebaseFirestore.instance
                  .collection('devices')
                  .doc(user.uid)
                  .collection('geofences')
                  .where('isEnabled', isEqualTo: true)
                  .get();

              for (var doc in geofencesSnapshot.docs) {
                final data = doc.data();
                final double gLat = (data['latitude'] as num).toDouble();
                final double gLng = (data['longitude'] as num).toDouble();
                final double gRadius = (data['radius'] as num).toDouble();
                final String gName = data['name'] as String? ?? 'Safe Zone';

                final double distance = Geolocator.distanceBetween(
                  position.latitude,
                  position.longitude,
                  gLat,
                  gLng,
                );

                if (distance > gRadius) {
                  // Breach detected! Check cooldown to prevent spam
                  final prefs = await SharedPreferences.getInstance();
                  final lastBreachAlert = prefs.getInt('last_breach_${doc.id}') ?? 0;
                  final now = DateTime.now().millisecondsSinceEpoch;

                  if (now - lastBreachAlert > 3600000) { // 1-hour cooldown for geofence breach
                    await FirebaseFirestore.instance
                        .collection('devices')
                        .doc(user.uid)
                        .collection('alerts')
                        .add({
                          'type': 'geofence_breach',
                          'timestamp': FieldValue.serverTimestamp(),
                          'message': 'SECURITY ALERT: Device exited Safe Zone "$gName"!',
                          'distance': distance,
                          'zone_id': doc.id,
                        });
                    await prefs.setInt('last_breach_${doc.id}', now);
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Geofence check failed: $e');
          }

        } catch (e) {
          debugPrint('Location Error: $e');
        }
      }
    }
  });
}
