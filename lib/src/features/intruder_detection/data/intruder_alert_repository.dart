import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

/// Handles the full intruder alert pipeline:
///   1. Upload captured photo → Firebase Storage
///   2. Get GPS coordinates
///   3. Write alert document → Firestore
///   4. Fire a local push notification
class IntruderAlertRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  IntruderAlertRepository() {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifs.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create the dedicated high-priority alert channel
    final androidPlugin =
        _localNotifs.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'secure_trace_intruder',
        'Intruder Alerts',
        description:
            'High-priority alerts when an intruder is detected on the device.',
        importance: Importance.max,
        playSound: true,
        enableLights: true,
        ledColor: Color(0xFFFF1744),
      ),
    );
  }

  /// Main entry point: called immediately after an intruder face is confirmed.
  Future<void> uploadAlert({
    required File capturedPhoto,
    required String reason, // e.g. "3_wrong_attempts"
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[IntruderAlert] No authenticated user — skipping upload.');
      return;
    }

    try {
      // ── 1. Upload photo to Firebase Storage ──────────────────────────────
      final photoId = const Uuid().v4();
      final storageRef = _storage
          .ref()
          .child('intruder_captures/${user.uid}/$photoId.jpg');

      final uploadTask = storageRef.putFile(
        capturedPhoto,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      final photoUrl = await snapshot.ref.getDownloadURL();
      debugPrint('[IntruderAlert] Photo uploaded: $photoUrl');

      // ── 2. Get GPS location ───────────────────────────────────────────────
      double? lat;
      double? lng;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (e) {
        debugPrint('[IntruderAlert] GPS unavailable: $e');
      }

      // ── 3. Save Firestore alert document ─────────────────────────────────
      await _firestore
          .collection('devices')
          .doc(user.uid)
          .collection('alerts')
          .add({
        'type': 'intruder_capture',
        'timestamp': FieldValue.serverTimestamp(),
        'message':
            '🚨 INTRUDER DETECTED: Someone entered the wrong password 3 times on your device!',
        'reason': reason,
        'photo_url': photoUrl,
        'location': lat != null
            ? {'latitude': lat, 'longitude': lng}
            : null,
        'face_match': false,
        'photo_id': photoId,
      });
      debugPrint('[IntruderAlert] Firestore alert saved.');

      // ── 4. Local push notification ────────────────────────────────────────
      await _fireLocalNotification(lat, lng);
    } catch (e) {
      debugPrint('[IntruderAlert] Upload failed: $e');
    }
  }

  Future<void> _fireLocalNotification(double? lat, double? lng) async {
    const androidDetails = AndroidNotificationDetails(
      'secure_trace_intruder',
      'Intruder Alerts',
      channelDescription:
          'Notifications when an intruder is detected on the device.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Intruder Detected',
      color: Color(0xFFFF1744),
      ledColor: Color(0xFFFF1744),
      ledOnMs: 1000,
      ledOffMs: 500,
      enableLights: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final locationText = lat != null
        ? 'Location: ${lat.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
        : 'Location: Unavailable';

    await _localNotifs.show(
      id: 9999,
      title: '🚨 Intruder Alert — SecureTrace',
      body: 'Wrong password × 3 detected. Photo captured. $locationText',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }
}

final intruderAlertRepositoryProvider = Provider<IntruderAlertRepository>(
  (_) => IntruderAlertRepository(),
);
