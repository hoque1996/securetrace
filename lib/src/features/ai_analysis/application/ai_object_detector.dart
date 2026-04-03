import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class AIObjectDetector {
  late ObjectDetector _objectDetector;
  late FaceDetector _faceDetector;

  AIObjectDetector() {
    // Basic human presence detection options
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
    
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
      ),
    );
  }

  Future<bool> processImage(CameraImage image) async {
    // Simplified: Check for any person or face presence
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return false;

    final objects = await _objectDetector.processImage(inputImage);
    for (var obj in objects) {
      for (var label in obj.labels) {
        if (label.text.toLowerCase().contains('person') || label.text.toLowerCase().contains('human')) {
          return true;
        }
      }
    }

    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isNotEmpty) return true;

    return false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // For MVP, we provide a placeholder. 
    // Manual YUV420 to InputImage conversion is required for production.
    return null; 
  }

  void dispose() {
    _objectDetector.close();
    _faceDetector.close();
  }
}
