import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the owner's face bounding-box / landmark data locally.
/// Nothing biometric ever leaves the device — only a raw photo is
/// uploaded to Firebase Storage when an *intruder* is detected.
class FaceStorageRepository {
  static const _kFaceEnrolledKey = 'owner_face_enrolled';
  static const _kFaceDataKey = 'owner_face_data';

  /// Returns true if the owner has completed face enrollment.
  Future<bool> isFaceEnrolled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFaceEnrolledKey) ?? false;
  }

  /// Persists a map of face feature landmarks (bounding box, contour points).
  Future<void> saveFaceData(Map<String, dynamic> faceData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFaceDataKey, jsonEncode(faceData));
    await prefs.setBool(_kFaceEnrolledKey, true);
  }

  /// Loads the stored owner face data. Returns null if not enrolled.
  Future<Map<String, dynamic>?> loadFaceData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFaceDataKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Clears enrollment (used on account delete / reset).
  Future<void> clearFaceData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFaceDataKey);
    await prefs.setBool(_kFaceEnrolledKey, false);
  }
}

final faceStorageRepositoryProvider = Provider<FaceStorageRepository>(
  (_) => FaceStorageRepository(),
);
