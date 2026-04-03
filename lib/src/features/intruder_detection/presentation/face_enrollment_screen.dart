import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/face_enrollment_controller.dart';

/// A premium face enrollment screen that walks the owner through
/// capturing their face for intruder detection.
class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  ConsumerState<FaceEnrollmentScreen> createState() =>
      _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  bool _cameraReady = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 1.0, end: 1.06).animate(_pulseController);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camera!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('[Enrollment] Camera init error: $e');
    }
  }

  Future<void> _captureAndEnroll() async {
    if (_camera == null || !_cameraReady) return;

    try {
      final xFile = await _camera!.takePicture();
      final photoFile = File(xFile.path);

      await ref
          .read(faceEnrollmentControllerProvider.notifier)
          .enrollFromFile(photoFile);
    } catch (e) {
      debugPrint('[Enrollment] Capture error: $e');
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enrollmentAsync = ref.watch(faceEnrollmentControllerProvider);

    ref.listen<AsyncValue<FaceEnrollmentState>>(
      faceEnrollmentControllerProvider,
      (_, next) {
        if (next.hasValue) {
          final status = next.value!.status;
          if (status == EnrollmentStatus.success) {
            _showSnackBar(
              '✅ Face enrolled successfully! Intruder detection is now active.',
              Colors.greenAccent,
            );
          } else if (status == EnrollmentStatus.noFaceDetected) {
            _showSnackBar(
              '⚠️ No face detected. Please look directly at the camera.',
              Colors.orangeAccent,
            );
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: enrollmentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (state) => _buildBody(state),
      ),
    );
  }

  Widget _buildBody(FaceEnrollmentState state) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(state),
          Expanded(child: _buildCameraView(state)),
          _buildBottomPanel(state),
        ],
      ),
    );
  }

  Widget _buildHeader(FaceEnrollmentState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 16, color: Color(0xFF00E5FF)),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Face Enrollment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Register your face for intruder detection',
                      style: TextStyle(
                        color: Color(0xFF8892A4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isEnrolled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user,
                          size: 12, color: Colors.greenAccent),
                      SizedBox(width: 4),
                      Text(
                        'ENROLLED',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView(FaceEnrollmentState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Camera preview or placeholder
            if (_cameraReady && _camera != null)
              AspectRatio(
                aspectRatio: _camera!.value.aspectRatio,
                child: CameraPreview(_camera!),
              )
            else
              Container(
                width: double.infinity,
                height: 340,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00E5FF)),
                ),
              ),

            // Face guide overlay
            if (_cameraReady)
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 200,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: state.isEnrolled
                          ? Colors.greenAccent.withValues(alpha: 0.7)
                          : const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(120),
                  ),
                ),
              ),

            // Corner brackets
            if (_cameraReady) ...[
              _buildCorner(Alignment.topLeft),
              _buildCorner(Alignment.topRight),
              _buildCorner(Alignment.bottomLeft),
              _buildCorner(Alignment.bottomRight),
            ],

            // Processing overlay
            if (state.status == EnrollmentStatus.processing)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing face...',
                      style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            // Success overlay
            if (state.status == EnrollmentStatus.success)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        border: Border.all(
                            color: Colors.greenAccent, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.greenAccent,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Face Enrolled!',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    final isTop = alignment == Alignment.topLeft ||
        alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft ||
        alignment == Alignment.bottomLeft;

    return Positioned(
      top: isTop ? 20 : null,
      bottom: !isTop ? 20 : null,
      left: isLeft ? 32 : null,
      right: !isLeft ? 32 : null,
      child: CustomPaint(
        size: const Size(22, 22),
        painter: _CornerPainter(
          isTop: isTop,
          isLeft: isLeft,
          color: const Color(0xFF00E5FF),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(FaceEnrollmentState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0E1A).withValues(alpha: 0),
            const Color(0xFF0A0E1A),
          ],
        ),
      ),
      child: Column(
        children: [
          _buildStatusCard(state),
          const SizedBox(height: 20),
          _buildActionButtons(state),
        ],
      ),
    );
  }

  Widget _buildStatusCard(FaceEnrollmentState state) {
    final (icon, text, color) = _getStatusContent(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _getStatusContent(FaceEnrollmentState state) {
    switch (state.status) {
      case EnrollmentStatus.success:
        return (
          Icons.verified_user,
          'Enrolled! Intruder detection is now active on this device.',
          Colors.greenAccent,
        );
      case EnrollmentStatus.noFaceDetected:
        return (
          Icons.face_retouching_off,
          state.errorMessage ?? 'No face detected. Please try again.',
          Colors.orangeAccent,
        );
      case EnrollmentStatus.processing:
        return (
          Icons.analytics_outlined,
          'Processing — please hold still...',
          const Color(0xFF00E5FF),
        );
      case EnrollmentStatus.error:
        return (
          Icons.error_outline,
          'An error occurred. Please try again.',
          Colors.redAccent,
        );
      default:
        return (
          Icons.face_retouching_natural,
          state.isEnrolled
              ? 'Your face is already enrolled. You can re-enroll to update it.'
              : 'Center your face in the oval guide and tap Enroll.',
          state.isEnrolled
              ? Colors.greenAccent
              : const Color(0xFF8892A4),
        );
    }
  }

  Widget _buildActionButtons(FaceEnrollmentState state) {
    final isProcessing = state.status == EnrollmentStatus.processing;

    return Row(
      children: [
        if (state.isEnrolled) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isProcessing
                  ? null
                  : () => ref
                      .read(faceEnrollmentControllerProvider.notifier)
                      .clearEnrollment(),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: isProcessing || !_cameraReady ? null : _captureAndEnroll,
            icon: isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2),
                  )
                : Icon(
                    state.isEnrolled ? Icons.refresh : Icons.face,
                    size: 20,
                  ),
            label: Text(
              isProcessing
                  ? 'Processing...'
                  : state.isEnrolled
                      ? 'Re-Enroll'
                      : 'Enroll Face',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              disabledBackgroundColor:
                  const Color(0xFF00E5FF).withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ── Corner bracket painter ───────────────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color color;

  _CornerPainter(
      {required this.isTop, required this.isLeft, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startX = isLeft ? 0.0 : size.width;
    final startY = isTop ? size.height : 0.0;
    final endX = isLeft ? size.width : 0.0;
    final endY = isTop ? 0.0 : size.height;

    final cornerX = isLeft ? 0.0 : size.width;
    final cornerY = isTop ? 0.0 : size.height;

    final path = Path()
      ..moveTo(startX, startY)
      ..lineTo(cornerX, cornerY)
      ..lineTo(endX, endY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
