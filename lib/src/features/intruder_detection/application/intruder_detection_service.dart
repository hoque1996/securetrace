import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../data/face_storage_repository.dart';
import '../data/intruder_alert_repository.dart';

enum IntruderCheckResult {
  ownerVerified,   // face matched — false alarm, do nothing
  intruderFound,   // face did NOT match — alert fired
  noFaceDetected,  // camera captured but no face in frame
  notEnrolled,     // owner has not enrolled their face yet
  error,           // something went wrong
}

/// Core service that orchestrates the intruder detection pipeline:
///   Camera init → capture → ML Kit face detection → compare → alert
class IntruderDetectionService {
  final FaceStorageRepository _faceStorage;
  final IntruderAlertRepository _alertRepo;

  IntruderDetectionService({
    required FaceStorageRepository faceStorage,
    required IntruderAlertRepository alertRepo,
  })  : _faceStorage = faceStorage,
        _alertRepo = alertRepo;

  /// Called from the IntruderOverlayScreen after 3 failed logins.
  /// Returns the result so the overlay can decide what to do next.
  Future<IntruderCheckResult> captureAndAnalyze() async {
    CameraController? controller;

    try {
      // ── Step 1: Check enrollment ──────────────────────────────────────────
      final isEnrolled = await _faceStorage.isFaceEnrolled();
      if (!isEnrolled) {
        debugPrint('[IntruderSvc] Owner not enrolled — skipping check.');
        return IntruderCheckResult.notEnrolled;
      }

      // ── Step 2: Initialize front camera ──────────────────────────────────
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      // Brief stabilization delay
      await Future.delayed(const Duration(milliseconds: 800));

      // ── Step 3: Capture frame ─────────────────────────────────────────────
      final XFile xFile = await controller.takePicture();
      final File capturedFile = File(xFile.path);
      debugPrint('[IntruderSvc] Photo captured: ${xFile.path}');

      // ── Step 4: ML Kit face detection ─────────────────────────────────────
      final inputImage = InputImage.fromFile(capturedFile);
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableLandmarks: true,
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final List<Face> detectedFaces = await detector.processImage(inputImage);
      await detector.close();

      if (detectedFaces.isEmpty) {
        debugPrint('[IntruderSvc] No face detected in captured frame.');
        capturedFile.deleteSync();
        return IntruderCheckResult.noFaceDetected;
      }

      // ── Step 5: Compare with owner face ───────────────────────────────────
      final ownerData = await _faceStorage.loadFaceData();
      final detectedFace = detectedFaces.first;
      final isOwner = _compareFaces(detectedFace, ownerData!);

      if (isOwner) {
        debugPrint('[IntruderSvc] Face matched owner — false alarm.');
        capturedFile.deleteSync();
        return IntruderCheckResult.ownerVerified;
      }

      // ── Step 6: Intruder confirmed — upload alert ─────────────────────────
      debugPrint('[IntruderSvc] INTRUDER CONFIRMED — uploading alert.');
      await _alertRepo.uploadAlert(
        capturedPhoto: capturedFile,
        reason: '3_wrong_attempts',
      );

      // Clean up local temp file after upload
      try { capturedFile.deleteSync(); } catch (_) {}

      return IntruderCheckResult.intruderFound;
    } catch (e) {
      debugPrint('[IntruderSvc] Error: $e');
      return IntruderCheckResult.error;
    } finally {
      await controller?.dispose();
    }
  }

  /// Enrolls the owner's face from a given [File] (taken by the enrollment
  /// screen). Extracts face landmarks and persists them locally.
  Future<bool> enrollOwnerFace(File photoFile) async {
    try {
      final inputImage = InputImage.fromFile(photoFile);
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableLandmarks: true,
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final faces = await detector.processImage(inputImage);
      await detector.close();

      if (faces.isEmpty) {
        debugPrint('[IntruderSvc] Enrollment: No face detected in photo.');
        return false;
      }

      final face = faces.first;
      final faceData = _extractFaceFeatures(face);
      await _faceStorage.saveFaceData(faceData);
      debugPrint('[IntruderSvc] Owner face enrolled successfully.');
      return true;
    } catch (e) {
      debugPrint('[IntruderSvc] Enrollment error: $e');
      return false;
    }
  }

  // ── Private Helpers ─────────────────────────────────────────────────────

  /// Extracts a serializable representation of landmark positions.
  Map<String, dynamic> _extractFaceFeatures(Face face) {
    final landmarks = <String, dynamic>{};

    for (final type in FaceLandmarkType.values) {
      final lm = face.landmarks[type];
      if (lm != null) {
        landmarks[type.name] = {
          'x': lm.position.x,
          'y': lm.position.y,
        };
      }
    }

    return {
      'boundingBox': {
        'left': face.boundingBox.left,
        'top': face.boundingBox.top,
        'right': face.boundingBox.right,
        'bottom': face.boundingBox.bottom,
        'width': face.boundingBox.width,
        'height': face.boundingBox.height,
      },
      'landmarks': landmarks,
      'enrolledAt': DateTime.now().toIso8601String(),
    };
  }

  /// Compares the captured face against stored owner data using landmark
  /// distances. Returns true if the similarity score exceeds the threshold.
  bool _compareFaces(Face captured, Map<String, dynamic> ownerData) {
    try {
      final ownerLandmarks =
          ownerData['landmarks'] as Map<String, dynamic>? ?? {};

      if (ownerLandmarks.isEmpty) {
        // Fall back to bounding-box size similarity if no landmarks stored
        return _boundingBoxSimilarity(captured, ownerData);
      }

      double totalScore = 0;
      int count = 0;

      for (final type in FaceLandmarkType.values) {
        final capturedLm = captured.landmarks[type];
        final ownerLmData = ownerLandmarks[type.name] as Map<String, dynamic>?;

        if (capturedLm != null && ownerLmData != null) {
          final ownerX = (ownerLmData['x'] as num).toDouble();
          final ownerY = (ownerLmData['y'] as num).toDouble();

          // Normalize by face bounding-box size so image scale doesn't matter
          final faceWidth = captured.boundingBox.width;
          final faceHeight = captured.boundingBox.height;

          final normDx =
              (capturedLm.position.x - ownerX).abs() / (faceWidth + 1);
          final normDy =
              (capturedLm.position.y - ownerY).abs() / (faceHeight + 1);

          final dist = sqrt(normDx * normDx + normDy * normDy);
          // Similarity: 1.0 = perfect match, 0.0 = completely different
          final similarity = max(0.0, 1.0 - dist);
          totalScore += similarity;
          count++;
        }
      }

      if (count == 0) return false;

      final avgSimilarity = totalScore / count;
      debugPrint(
          '[IntruderSvc] Face similarity score: ${(avgSimilarity * 100).toStringAsFixed(1)}%');

      // Threshold: ≥ 72% similarity → same person
      return avgSimilarity >= 0.72;
    } catch (e) {
      debugPrint('[IntruderSvc] Comparison error: $e');
      return false;
    }
  }

  bool _boundingBoxSimilarity(Face captured, Map<String, dynamic> ownerData) {
    final ownerBb = ownerData['boundingBox'] as Map<String, dynamic>? ?? {};
    if (ownerBb.isEmpty) return false;

    final ownerW = (ownerBb['width'] as num?)?.toDouble() ?? 0;
    final ownerH = (ownerBb['height'] as num?)?.toDouble() ?? 0;
    final captW = captured.boundingBox.width;
    final captH = captured.boundingBox.height;

    if (ownerW == 0 || ownerH == 0) return false;

    final wRatio = min(captW, ownerW) / max(captW, ownerW);
    final hRatio = min(captH, ownerH) / max(captH, ownerH);
    final similarity = (wRatio + hRatio) / 2;

    debugPrint('[IntruderSvc] BBox similarity: ${(similarity * 100).toStringAsFixed(1)}%');
    return similarity >= 0.72;
  }
}

// ── Riverpod Provider ────────────────────────────────────────────────────────

final intruderDetectionServiceProvider = Provider<IntruderDetectionService>(
  (ref) => IntruderDetectionService(
    faceStorage: ref.read(faceStorageRepositoryProvider),
    alertRepo: ref.read(intruderAlertRepositoryProvider),
  ),
);
