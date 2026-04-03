import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/intruder_detection_service.dart';
import '../data/face_storage_repository.dart';

enum EnrollmentStatus {
  idle,
  capturing,
  processing,
  success,
  noFaceDetected,
  error,
}

class FaceEnrollmentState {
  final EnrollmentStatus status;
  final bool isEnrolled;
  final String? errorMessage;

  const FaceEnrollmentState({
    this.status = EnrollmentStatus.idle,
    this.isEnrolled = false,
    this.errorMessage,
  });

  FaceEnrollmentState copyWith({
    EnrollmentStatus? status,
    bool? isEnrolled,
    String? errorMessage,
  }) {
    return FaceEnrollmentState(
      status: status ?? this.status,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FaceEnrollmentController extends AsyncNotifier<FaceEnrollmentState> {
  late final IntruderDetectionService _service;
  late final FaceStorageRepository _faceStorage;

  @override
  FutureOr<FaceEnrollmentState> build() async {
    _service = ref.read(intruderDetectionServiceProvider);
    _faceStorage = ref.read(faceStorageRepositoryProvider);
    final isEnrolled = await _faceStorage.isFaceEnrolled();
    return FaceEnrollmentState(isEnrolled: isEnrolled);
  }

  /// Enroll the owner's face from a file captured by the enrollment screen.
  Future<void> enrollFromFile(File photoFile) async {
    final currentState = state.value ??
        const FaceEnrollmentState(status: EnrollmentStatus.processing);

    state = AsyncData(currentState.copyWith(status: EnrollmentStatus.processing));

    final success = await _service.enrollOwnerFace(photoFile);

    if (success) {
      state = AsyncData(currentState.copyWith(
        status: EnrollmentStatus.success,
        isEnrolled: true,
      ));
    } else {
      state = AsyncData(currentState.copyWith(
        status: EnrollmentStatus.noFaceDetected,
        errorMessage: 'No face detected. Please look directly at the camera.',
      ));
    }
  }

  /// Clears the stored face enrollment.
  Future<void> clearEnrollment() async {
    await _faceStorage.clearFaceData();
    final currentState = state.value ?? const FaceEnrollmentState();
    state = AsyncData(currentState.copyWith(
      status: EnrollmentStatus.idle,
      isEnrolled: false,
    ));
  }
}

final faceEnrollmentControllerProvider =
    AsyncNotifierProvider<FaceEnrollmentController, FaceEnrollmentState>(
  FaceEnrollmentController.new,
);
